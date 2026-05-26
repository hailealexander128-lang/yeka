using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;
using Dapper;

namespace CleaningManagmentSystem.Pages.Dashboard.Staff
{
    public class ApprovalsModel : PageModel
    {
        private readonly IConfiguration _configuration;
        private readonly string _connectionString;

        public ApprovalsModel(IConfiguration configuration)
        {
            _configuration = configuration;
            _connectionString = configuration.GetConnectionString("DefaultConnection") 
                ?? throw new InvalidOperationException("Connection string not found.");
        }

        public List<dynamic> PendingSubmissions { get; set; } = new List<dynamic>();
        public List<dynamic> HistorySubmissions { get; set; } = new List<dynamic>();

        [BindProperty(SupportsGet = true)]
        public string SearchQuery { get; set; } = "";

        public decimal DefaultPricePerKg { get; set; } = 1.4m;

        public async Task OnGetAsync()
        {
            using var connection = new MySqlConnection(_connectionString);

            try
            {
                var value = await connection.QueryFirstOrDefaultAsync<string>(
                    "SELECT setting_value FROM system_settings WHERE setting_key = 'DefaultPricePerKg'");
                if (value != null && decimal.TryParse(value, out var price))
                {
                    DefaultPricePerKg = price;
                }
            }
            catch { }

            var query = @"
                SELECT * FROM (
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
                ) as combined
                WHERE status = 'Pending' ";

            if (!string.IsNullOrEmpty(SearchQuery))
            {
                query += " AND (weredaName LIKE @Search OR driverName LIKE @Search OR vehicleName LIKE @Search OR mahberatName LIKE @Search) ";
            }
            query += " ORDER BY registered_at DESC";

            PendingSubmissions = (await connection.QueryAsync(query, new { Search = "%" + SearchQuery + "%" })).ToList();

            var historyQuery = @"
                SELECT * FROM (
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
                ) as combined
                WHERE status != 'Pending' ";

            if (!string.IsNullOrEmpty(SearchQuery))
            {
                historyQuery += " AND (weredaName LIKE @Search OR driverName LIKE @Search OR vehicleName LIKE @Search OR mahberatName LIKE @Search) ";
            }
            historyQuery += " ORDER BY registered_at DESC LIMIT 50";

            HistorySubmissions = (await connection.QueryAsync(historyQuery, new { Search = "%" + SearchQuery + "%" })).ToList();
        }

        public async Task<IActionResult> OnPostApproveAsync(int id, string receiptType, decimal totalPrice)
        {
            using var connection = new MySqlConnection(_connectionString);
            var table = receiptType == "Outsource" ? "outsource_receipts" : "staff_receipts";
            
            if (totalPrice > 0)
            {
                await connection.ExecuteAsync($"UPDATE {table} SET status = 'Approved', price = @TotalPrice WHERE id = @Id", new { Id = id, TotalPrice = totalPrice });
            }
            else
            {
                await connection.ExecuteAsync($"UPDATE {table} SET status = 'Approved' WHERE id = @Id", new { Id = id });
            }
            return RedirectToPage();
        }

        public async Task<IActionResult> OnPostRejectAsync(int id, string receiptType)
        {
            using var connection = new MySqlConnection(_connectionString);
            var table = receiptType == "Outsource" ? "outsource_receipts" : "staff_receipts";
            await connection.ExecuteAsync($"UPDATE {table} SET status = 'Rejected' WHERE id = @Id", new { Id = id });
            return RedirectToPage();
        }
    }
}
