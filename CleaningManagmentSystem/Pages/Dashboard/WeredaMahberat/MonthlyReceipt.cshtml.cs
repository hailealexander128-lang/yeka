using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.Mvc;
using MySqlConnector;
using Dapper;
using CleaningManagmentSystem.Models;

namespace CleaningManagmentSystem.Pages.Dashboard.WeredaMahberat
{
    public class MonthlyReceiptModel : PageModel
    {
        private readonly string _connectionString;

        [BindProperty]
        public MonthlyReceipt? Receipt { get; set; }

        [BindProperty]
        public string? SearchTerm { get; set; }

        [BindProperty]
        public string? FilterMonth { get; set; }

        [BindProperty]
        public int? FilterYear { get; set; }

        public IEnumerable<MonthlyReceipt>? Receipts { get; set; }

        public MonthlyReceiptModel(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection") ?? "";
        }

        public IActionResult OnGet()
        {
            var userName = HttpContext.Session.GetString("UserName");
            if (string.IsNullOrEmpty(userName))
            {
                Console.WriteLine("[MonthlyReceipt] No UserName in session, redirecting to Login");
                return RedirectToPage("/Login");
            }

            Console.WriteLine($"[MonthlyReceipt] OnGet called by UserName: {userName}");
            LoadReceipts();
            return Page();
        }

        public IActionResult OnPostAddReceipt()
        {
            var userName = HttpContext.Session.GetString("UserName");
            if (string.IsNullOrEmpty(userName))
            {
                return RedirectToPage("/Login");
            }

            if (Receipt == null || string.IsNullOrEmpty(Receipt.ReceiptNumber))
            {
                ModelState.AddModelError(string.Empty, "Receipt Number is required");
                LoadReceipts();
                return Page();
            }

            try
            {
                using var connection = new MySqlConnection(_connectionString);

                var existingReceipt = connection.QueryFirstOrDefault<MonthlyReceipt>(
                    "SELECT id FROM monthly_receipts WHERE receipt_number = @ReceiptNumber",
                    new { Receipt.ReceiptNumber });

                if (existingReceipt != null)
                {
                    ModelState.AddModelError(string.Empty, "Receipt number already exists");
                    LoadReceipts();
                    return Page();
                }

                connection.Execute(
                    @"INSERT INTO monthly_receipts (receipt_number, month, year, total_amount, paid_amount, balance, status, source, created_at, updated_at)
                    VALUES (@ReceiptNumber, @Month, @Year, @TotalAmount, @PaidAmount, @Balance, @Status, @Source, NOW(), NOW())",
                    new
                    {
                        Receipt.ReceiptNumber,
                        Receipt.Month,
                        Receipt.Year,
                        Receipt.TotalAmount,
                        Receipt.PaidAmount,
                        Receipt.Balance,
                        Receipt.Status,
                        Receipt.Source
                    });

                Console.WriteLine($"[MonthlyReceipt] Added new receipt: {Receipt.ReceiptNumber}");
                TempData["SuccessMessage"] = "Receipt added successfully";
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[MonthlyReceipt] Add error: {ex.Message}");
                ModelState.AddModelError(string.Empty, "Error adding receipt. Please try again.");
            }

            return RedirectToPage();
        }

        public IActionResult OnPostUpdateReceipt()
        {
            var userName = HttpContext.Session.GetString("UserName");
            if (string.IsNullOrEmpty(userName))
            {
                return RedirectToPage("/Login");
            }

            if (Receipt == null || Receipt.Id <= 0)
            {
                ModelState.AddModelError(string.Empty, "Invalid receipt ID");
                LoadReceipts();
                return Page();
            }

            try
            {
                using var connection = new MySqlConnection(_connectionString);

                Receipt.Balance = Receipt.TotalAmount - Receipt.PaidAmount;

                var affectedRows = connection.Execute(
                    @"UPDATE monthly_receipts 
                    SET receipt_number = @ReceiptNumber, month = @Month, year = @Year, 
                        total_amount = @TotalAmount, paid_amount = @PaidAmount, balance = @Balance,
                        status = @Status, source = @Source, updated_at = NOW()
                    WHERE id = @Id",
                    new
                    {
                        Receipt.Id,
                        Receipt.ReceiptNumber,
                        Receipt.Month,
                        Receipt.Year,
                        Receipt.TotalAmount,
                        Receipt.PaidAmount,
                        Receipt.Balance,
                        Receipt.Status,
                        Receipt.Source
                    });

                if (affectedRows > 0)
                {
                    Console.WriteLine($"[MonthlyReceipt] Updated receipt ID: {Receipt.Id}");
                    TempData["SuccessMessage"] = "Receipt updated successfully";
                }
                else
                {
                    ModelState.AddModelError(string.Empty, "Receipt not found");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[MonthlyReceipt] Update error: {ex.Message}");
                ModelState.AddModelError(string.Empty, "Error updating receipt. Please try again.");
            }

            return RedirectToPage();
        }

        public IActionResult OnPostDeleteReceipt(int id)
        {
            var userName = HttpContext.Session.GetString("UserName");
            if (string.IsNullOrEmpty(userName))
            {
                return RedirectToPage("/Login");
            }

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                var affectedRows = connection.Execute(
                    "DELETE FROM monthly_receipts WHERE id = @Id",
                    new { Id = id });

                if (affectedRows > 0)
                {
                    Console.WriteLine($"[MonthlyReceipt] Deleted receipt ID: {id}");
                    TempData["SuccessMessage"] = "Receipt deleted successfully";
                }
                else
                {
                    TempData["ErrorMessage"] = "Receipt not found";
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[MonthlyReceipt] Delete error: {ex.Message}");
                TempData["ErrorMessage"] = "Error deleting receipt";
            }

            return RedirectToPage();
        }

        private void LoadReceipts()
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);

                string sql = "SELECT * FROM monthly_receipts WHERE 1=1";
                var parameters = new DynamicParameters();

                if (!string.IsNullOrEmpty(FilterMonth))
                {
                    sql += " AND month = @Month";
                    parameters.Add("Month", FilterMonth);
                }

                if (FilterYear.HasValue && FilterYear > 0)
                {
                    sql += " AND year = @Year";
                    parameters.Add("Year", FilterYear.Value);
                }

                if (!string.IsNullOrEmpty(SearchTerm))
                {
                    sql += " AND (receipt_number LIKE @Search OR source LIKE @Search)";
                    parameters.Add("Search", $"%{SearchTerm}%");
                }

                sql += " ORDER BY year DESC, month DESC, created_at DESC";

                var allReceipts = connection.Query<MonthlyReceipt>(sql, parameters).ToList();

                if (!string.IsNullOrEmpty(SearchTerm) && (string.IsNullOrEmpty(FilterMonth) && !FilterYear.HasValue))
                {
                    Receipts = allReceipts;
                }
                else
                {
                    Receipts = allReceipts;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[MonthlyReceipt] Load error: {ex.Message}");
                Receipts = new List<MonthlyReceipt>();
            }
        }
    }
}
