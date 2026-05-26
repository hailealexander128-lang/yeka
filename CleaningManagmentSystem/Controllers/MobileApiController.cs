using Microsoft.AspNetCore.Mvc;
using MySqlConnector;
using Dapper;
using System.Data;
using Microsoft.Extensions.Configuration;

namespace CleaningManagmentSystem.Controllers
{
    [Route("api/mobile")]
    [ApiController]
    public class MobileApiController : ControllerBase
    {
        private readonly string _connectionString;

        public MobileApiController(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection") 
                ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
        }

        private IDbConnection CreateConnection() => new MySqlConnection(_connectionString);

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            using var connection = CreateConnection();
            var user = await connection.QueryFirstOrDefaultAsync<UserResponse>(
                @"SELECT id, name, role, phone 
                  FROM users 
                  WHERE email = @Email AND password = @Password AND is_active = TRUE",
                new { Email = request.Username, Password = request.Password });

            if (user == null)
                return Unauthorized(new { message = "Invalid credentials or inactive account" });

            // If the user is a driver, try to fetch their assigned vehicle
            if (user.Role.ToLower() == "driver")
            {
                var vehicle = await connection.QueryFirstOrDefaultAsync(
                    "SELECT id, plate_number FROM vehicles WHERE driver_id = @Id", new { Id = user.Id });
                
                if (vehicle != null)
                {
                    user.VehicleId = vehicle.id;
                    user.VehicleName = vehicle.plate_number;
                }
            }

            return Ok(user);
        }

        [HttpGet("weredas")]
        public async Task<IActionResult> GetWeredas()
        {
            using var connection = CreateConnection();
            var weredas = await connection.QueryAsync(
                "SELECT id, name FROM weredas WHERE is_active = TRUE ORDER BY name ASC");
            return Ok(weredas);
        }

        [HttpGet("mahberats")]
        public async Task<IActionResult> GetMahberats()
        {
            using var connection = CreateConnection();
            var mahberats = await connection.QueryAsync(
                "SELECT id, name FROM mahberats WHERE is_active = TRUE ORDER BY name ASC");
            return Ok(mahberats);
        }

        [HttpGet("companies")]
        public async Task<IActionResult> GetCompanies()
        {
            using var connection = CreateConnection();
            var companies = await connection.QueryAsync(
                "SELECT id, company_name as name FROM outsource_companies WHERE status = 'Active' ORDER BY company_name ASC");
            return Ok(companies);
        }

        [HttpGet("vehicles")]
        public async Task<IActionResult> GetVehicles()
        {
            using var connection = CreateConnection();
            var vehicles = await connection.QueryAsync(
                "SELECT id, CONCAT(model, ' - ', plate_number) as name FROM vehicles WHERE status = 'Available' ORDER BY plate_number ASC");
            return Ok(vehicles);
        }

        [HttpPost("submit")]
        public async Task<IActionResult> SubmitReceipt([FromBody] ReceiptSubmission request)
        {
            using var connection = CreateConnection();
            
            var isOutsource = request.ReceiptType == "Outsource";
            
            var weredaName = await connection.QueryFirstOrDefaultAsync<string>(
                "SELECT name FROM weredas WHERE id = @Id", new { Id = request.WeredaId });
                
            string entityName = null;
            if (isOutsource) {
                entityName = await connection.QueryFirstOrDefaultAsync<string>(
                    "SELECT company_name FROM outsource_companies WHERE id = @Id", new { Id = request.MahberatId });
            } else {
                entityName = await connection.QueryFirstOrDefaultAsync<string>(
                    "SELECT name FROM mahberats WHERE id = @Id", new { Id = request.MahberatId });
            }
                
            var vehicleName = request.VehicleId.HasValue 
                ? await connection.QueryFirstOrDefaultAsync<string>(
                    "SELECT plate_number FROM vehicles WHERE id = @Id", new { Id = request.VehicleId }) 
                : null;
            var driverName = await connection.QueryFirstOrDefaultAsync<string>(
                "SELECT name FROM users WHERE id = @Id", new { Id = request.UserId });

            if (isOutsource)
            {
                await connection.ExecuteAsync(
                      @"INSERT INTO outsource_receipts 
                      (wereda_id, wereda_name, company_id, company_name, vehicle_id, plate_number, 
                       driver_id, driver_name, receipt_time, receipt_date, kilogram, price, registered_by, status, notes, image_url)
                      VALUES 
                      (@WeredaId, @WeredaName, @CompanyId, @CompanyName, @VehicleId, @PlateNumber,
                       @DriverId, @DriverName, @Time, @Date, @Kilogram, @Price, 'MobileApp', 'Pending', @Notes, @ImageUrl)",
                    new 
                    { 
                        WeredaId = request.WeredaId, WeredaName = weredaName,
                        CompanyId = request.MahberatId, CompanyName = entityName,
                        VehicleId = request.VehicleId, PlateNumber = vehicleName,
                        DriverId = request.UserId, DriverName = driverName,
                        Time = request.Time, Date = request.Date,
                        Kilogram = request.Kilogram, Price = request.Total,
                        Notes = request.Notes, ImageUrl = request.ImageUrl
                    });
            }
            else
            {
                await connection.ExecuteAsync(
                      @"INSERT INTO staff_receipts 
                      (wereda_id, wereda_name, mahberat_id, mahberat_name, vehicle_id, plate_number, 
                       driver_id, driver_name, receipt_time, receipt_date, kilogram, price, registered_by, status, notes, image_url, latitude, longitude)
                      VALUES 
                      (@WeredaId, @WeredaName, @MahberatId, @MahberatName, @VehicleId, @PlateNumber,
                       @DriverId, @DriverName, @Time, @Date, @Kilogram, @Price, 'MobileApp', 'Pending', @Notes, @ImageUrl, @Latitude, @Longitude)",
                    new 
                    { 
                        WeredaId = request.WeredaId, WeredaName = weredaName,
                        MahberatId = request.MahberatId, MahberatName = entityName,
                        VehicleId = request.VehicleId, PlateNumber = vehicleName,
                        DriverId = request.UserId, DriverName = driverName,
                        Time = request.Time, Date = request.Date,
                        Kilogram = request.Kilogram, Price = request.Total,
                        Notes = request.Notes, ImageUrl = request.ImageUrl,
                        Latitude = request.Latitude, Longitude = request.Longitude
                    });
            }

            return Ok(new { success = true });
        }

        [HttpGet("history/{userId}")]
        public async Task<IActionResult> GetHistory(int userId)
        {
            using var connection = CreateConnection();
            var history = await connection.QueryAsync(
                @"SELECT * FROM (
                    SELECT 
                        id, 
                        wereda_name as weredaName, 
                        mahberat_name as mahberatName, 
                        kilogram, 
                        price as total, 
                        DATE_FORMAT(receipt_date, '%Y-%m-%d') as date, 
                        TIME_FORMAT(receipt_time, '%H:%i') as time, 
                        status,
                        notes,
                        image_url as imageUrl,
                        registered_at
                    FROM staff_receipts 
                    WHERE driver_id = @UserId 
                    
                    UNION ALL
                    
                    SELECT 
                        id, 
                        wereda_name as weredaName, 
                        company_name as mahberatName, 
                        kilogram, 
                        price as total, 
                        DATE_FORMAT(receipt_date, '%Y-%m-%d') as date, 
                        TIME_FORMAT(receipt_time, '%H:%i') as time, 
                        status,
                        notes,
                        image_url as imageUrl,
                        registered_at
                    FROM outsource_receipts 
                    WHERE driver_id = @UserId 
                ) as combined
                ORDER BY registered_at DESC",
                new { UserId = userId });
            return Ok(history);
        }

        [HttpGet("pending")]
        public async Task<IActionResult> GetPendingSubmissions()
        {
            using var connection = CreateConnection();
            var pending = await connection.QueryAsync(
                @"SELECT * FROM (
                    SELECT 
                        id, 
                        'Mahberat' as receiptType,
                        wereda_name as weredaName, 
                        mahberat_name as mahberatName, 
                        driver_name as driverName,
                        plate_number as vehicleName,
                        kilogram, 
                        price as total, 
                        DATE_FORMAT(receipt_date, '%Y-%m-%d') as date, 
                        TIME_FORMAT(receipt_time, '%H:%i') as time, 
                        status,
                        notes,
                        image_url as imageUrl,
                        registered_at
                    FROM staff_receipts 
                    WHERE status = 'Pending' 
                    
                    UNION ALL
                    
                    SELECT 
                        id, 
                        'Outsource' as receiptType,
                        wereda_name as weredaName, 
                        company_name as mahberatName, 
                        driver_name as driverName,
                        plate_number as vehicleName,
                        kilogram, 
                        price as total, 
                        DATE_FORMAT(receipt_date, '%Y-%m-%d') as date, 
                        TIME_FORMAT(receipt_time, '%H:%i') as time, 
                        status,
                        notes,
                        image_url as imageUrl,
                        registered_at
                    FROM outsource_receipts 
                    WHERE status = 'Pending' 
                ) as combined
                ORDER BY registered_at DESC");
            return Ok(pending);
        }

        [HttpPost("submissions/{id}/status")]
        public async Task<IActionResult> UpdateSubmissionStatus(int id, [FromBody] StatusUpdateRequest request)
        {
            using var connection = CreateConnection();
            var table = request.ReceiptType == "Outsource" ? "outsource_receipts" : "staff_receipts";
            var result = await connection.ExecuteAsync(
                $"UPDATE {table} SET status = @Status WHERE id = @Id",
                new { Status = request.Status, Id = id });

            if (result > 0)
                return Ok(new { success = true });
            return BadRequest(new { message = "Update failed or record not found" });
        }

        [HttpPost("upload-image")]
        [Consumes("multipart/form-data")]
        public async Task<IActionResult> UploadImage([FromForm] IFormFile file)
        {
            if (file == null || file.Length == 0)
                return BadRequest(new { message = "No file provided" });

            var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads");
            if (!Directory.Exists(uploadsFolder))
                Directory.CreateDirectory(uploadsFolder);

            var uniqueFileName = $"{Guid.NewGuid()}{Path.GetExtension(file.FileName)}";
            var filePath = Path.Combine(uploadsFolder, uniqueFileName);

            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            var imageUrl = $"/uploads/{uniqueFileName}";
            return Ok(new { url = imageUrl });
        }
    }

    public class LoginRequest
    {
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
    }

    public class UserResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Role { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public int? VehicleId { get; set; }
        public string? VehicleName { get; set; }
    }

    public class ReceiptSubmission
    {
        public string ReceiptType { get; set; } = "Mahberat";
        public int UserId { get; set; }
        public string Role { get; set; } = string.Empty;
        public int WeredaId { get; set; }
        public int MahberatId { get; set; }
        public int? VehicleId { get; set; }
        public decimal Kilogram { get; set; }
        public decimal Rate { get; set; }
        public decimal Total { get; set; }
        public string Date { get; set; } = string.Empty;
        public string Time { get; set; } = string.Empty;
        public string? ImageUrl { get; set; }
        public string Notes { get; set; } = string.Empty;
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
    }

    public class StatusUpdateRequest
    {
        public string Status { get; set; } = string.Empty;
        public string ReceiptType { get; set; } = "Mahberat";
    }
}
