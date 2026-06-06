using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;
using Dapper;
using System.ComponentModel.DataAnnotations;

namespace CleaningManagmentSystem.Pages.Dashboard.Staff
{
    [IgnoreAntiforgeryToken]
    public class PrivateCompanyReceiptModel : PageModel
    {
        private readonly string _connectionString;

        [BindProperty] public int    CompanyId  { get; set; }
        [BindProperty] public int    WeredaId   { get; set; }
        [BindProperty] public int    VehicleId  { get; set; }
        [BindProperty] public int    DriverId   { get; set; }

        [BindProperty]
        [Required(ErrorMessage = "Date is required")]
        public DateTime Date { get; set; }

        [BindProperty]
        [Required(ErrorMessage = "Time is required")]
        public string TimeString { get; set; } = "";

        [BindProperty]
        [Required(ErrorMessage = "Kilogram is required")]
        [Range(0.01, double.MaxValue)]
        public decimal Kilogram { get; set; }

        [BindProperty]
        [Required(ErrorMessage = "Price per KG is required")]
        [Range(0.01, double.MaxValue)]
        public decimal Price { get; set; }

        [BindProperty] public string? Notes { get; set; }

        // Filter
        [BindProperty(SupportsGet = true)] public int?      FilterCompanyId  { get; set; }
        [BindProperty(SupportsGet = true)] public int?      FilterWeredaId   { get; set; }
        [BindProperty(SupportsGet = true)] public DateTime? FilterStartDate  { get; set; }
        [BindProperty(SupportsGet = true)] public DateTime? FilterEndDate    { get; set; }

        public decimal DefaultPricePerKg { get; set; } = 1.4m;

        public List<dynamic> Companies      { get; set; } = new();
        public List<dynamic> Weredas        { get; set; } = new();
        public List<dynamic> Vehicles       { get; set; } = new();
        public List<dynamic> Drivers        { get; set; } = new();
        public List<dynamic> RecentReceipts { get; set; } = new();

        public string Message   { get; set; } = "";
        public bool   IsSuccess { get; set; }

        public PrivateCompanyReceiptModel(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection") ?? "";
        }

        public IActionResult OnGet()
        {
            var userName = HttpContext.Session.GetString("UserName");
            var userRole = HttpContext.Session.GetString("UserRole");
            if (string.IsNullOrEmpty(userName) ||
                (userRole?.ToLower() != "staff" && userRole?.ToLower() != "manager"))
                return RedirectToPage("/Login");

            LoadData();
            LoadDefaults();
            return Page();
        }

        public IActionResult OnPost()
        {
            var userName = HttpContext.Session.GetString("UserName");
            var userRole = HttpContext.Session.GetString("UserRole");
            if (string.IsNullOrEmpty(userName) ||
                (userRole?.ToLower() != "staff" && userRole?.ToLower() != "manager"))
                return RedirectToPage("/Login");

            if (!ModelState.IsValid) { LoadData(); LoadDefaults(); return Page(); }

            try
            {
                TimeSpan receiptTime = TimeSpan.Zero;
                if (!string.IsNullOrEmpty(TimeString))
                    TimeSpan.TryParse(TimeString, out receiptTime);

                using var conn = new MySqlConnection(_connectionString);

                // Resolve names
                var companyName = conn.QueryFirstOrDefault<string>(
                    "SELECT company_name FROM private_cleaning_companies WHERE id=@Id", new { Id = CompanyId }) ?? "";
                var weredaName  = conn.QueryFirstOrDefault<string>(
                    "SELECT name FROM weredas WHERE id=@Id", new { Id = WeredaId }) ?? "";
                var platNumber  = conn.QueryFirstOrDefault<string>(
                    "SELECT plate_number FROM vehicles WHERE id=@Id", new { Id = VehicleId }) ?? "";
                var driverName  = conn.QueryFirstOrDefault<string>(
                    "SELECT name FROM users WHERE id=@Id", new { Id = DriverId })
                    ?? conn.QueryFirstOrDefault<string>(
                    "SELECT full_name FROM drivers WHERE id=@Id", new { Id = DriverId }) ?? "";

                conn.Execute(@"
                    INSERT INTO private_company_receipts
                      (company_id, company_name, wereda_id, wereda_name,
                       vehicle_id, plate_number, driver_id, driver_name,
                       receipt_time, receipt_date, kilogram, price,
                       total_amount, notes, registered_by, status, registered_at)
                    VALUES
                      (@CompanyId, @CompanyName, @WeredaId, @WeredaName,
                       @VehicleId, @PlateNumber, @DriverId, @DriverName,
                       @ReceiptTime, @Date, @Kilogram, @Price,
                       @Total, @Notes, @RegisteredBy, 'Registered', NOW())",
                    new {
                        CompanyId, CompanyName = companyName,
                        WeredaId,  WeredaName  = weredaName,
                        VehicleId, PlateNumber = platNumber,
                        DriverId,  DriverName  = driverName,
                        ReceiptTime = receiptTime,
                        Date, Kilogram, Price,
                        Total = Kilogram * Price,
                        Notes = Notes ?? "",
                        RegisteredBy = userName
                    });

                Message   = "Private company receipt registered successfully!";
                IsSuccess = true;

                // Reset
                CompanyId = WeredaId = VehicleId = DriverId = 0;
                TimeString = ""; Date = default; Kilogram = 0; Price = 0; Notes = "";
            }
            catch (Exception ex)
            {
                Message   = $"Error: {ex.Message}";
                IsSuccess = false;
            }

            LoadData(); LoadDefaults();
            return Page();
        }

        public IActionResult OnPostDelete(int id)
        {
            var userName = HttpContext.Session.GetString("UserName");
            if (string.IsNullOrEmpty(userName)) return RedirectToPage("/Login");
            try
            {
                using var conn = new MySqlConnection(_connectionString);
                conn.Execute("DELETE FROM private_company_receipts WHERE id=@Id", new { Id = id });
                Message = "Receipt deleted."; IsSuccess = true;
            }
            catch (Exception ex) { Message = $"Error: {ex.Message}"; IsSuccess = false; }
            LoadData(); LoadDefaults(); return Page();
        }

        public IActionResult OnPostMarkPaid(int id)
        {
            var userName = HttpContext.Session.GetString("UserName");
            if (string.IsNullOrEmpty(userName)) return RedirectToPage("/Login");
            try
            {
                using var conn = new MySqlConnection(_connectionString);
                conn.Execute("UPDATE private_company_receipts SET status='Paid' WHERE id=@Id", new { Id = id });
                Message = "Marked as Paid."; IsSuccess = true;
            }
            catch (Exception ex) { Message = $"Error: {ex.Message}"; IsSuccess = false; }
            LoadData(); LoadDefaults(); return Page();
        }

        private void LoadDefaults()
        {
            try
            {
                using var conn = new MySqlConnection(_connectionString);
                var val = conn.QueryFirstOrDefault<string>(
                    "SELECT setting_value FROM system_settings WHERE setting_key='DefaultPricePerKg'");
                if (val != null && decimal.TryParse(val, out var p)) DefaultPricePerKg = p;
                if (Price == 0) Price = DefaultPricePerKg;
            }
            catch { }
        }

        private void LoadData()
        {
            try
            {
                using var conn = new MySqlConnection(_connectionString);

                Companies = conn.Query<dynamic>(
                    "SELECT id, company_name FROM private_cleaning_companies WHERE is_active=1 ORDER BY company_name").ToList();
                Weredas = conn.Query<dynamic>(
                    "SELECT id, name FROM weredas WHERE is_active=1 ORDER BY name").ToList();
                Vehicles = conn.Query<dynamic>(
                    "SELECT id, plate_number, model FROM vehicles ORDER BY plate_number").ToList();
                Drivers = conn.Query<dynamic>(
                    "SELECT id, name FROM users WHERE role='Driver' AND is_active=1 ORDER BY name").ToList();

                var q = "SELECT * FROM private_company_receipts WHERE 1=1";
                var p = new DynamicParameters();
                if (FilterCompanyId > 0) { q += " AND company_id=@CId"; p.Add("CId", FilterCompanyId); }
                if (FilterWeredaId  > 0) { q += " AND wereda_id=@WId";  p.Add("WId", FilterWeredaId);  }
                if (FilterStartDate.HasValue) { q += " AND receipt_date>=@S"; p.Add("S", FilterStartDate.Value); }
                if (FilterEndDate.HasValue)   { q += " AND receipt_date<=@E"; p.Add("E", FilterEndDate.Value);   }
                q += " ORDER BY registered_at DESC LIMIT 50";

                RecentReceipts = conn.Query<dynamic>(q, p).ToList();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[PrivateCompanyReceipt] LoadData error: {ex.Message}");
            }
        }
    }
}
