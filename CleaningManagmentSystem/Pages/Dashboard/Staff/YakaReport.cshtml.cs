using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;
using Dapper;

namespace CleaningManagmentSystem.Pages.Dashboard.Staff
{
    public class YakaReportModel : PageModel
    {
        private readonly string _connectionString;

        [BindProperty]
        public int Id { get; set; }

        [BindProperty]
        public string ReportTitle { get; set; } = "";

        [BindProperty]
        public string ReportDescription { get; set; } = "";

        [BindProperty]
        public string YakaZone { get; set; } = "";

        [BindProperty]
        public DateTime ReportDate { get; set; }

        [BindProperty]
        public string AttachmentUrl { get; set; } = "";

        [BindProperty]
        public string Status { get; set; } = "Pending";

        public List<YakaReport> YakaReports { get; set; } = new();
        public string ErrorMessage { get; set; } = "";

        public YakaReportModel(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection") ?? "";
        }

        public IActionResult OnGet()
        {
            var userId = HttpContext.Session.GetInt32("UserId");
            if (userId == null)
                return RedirectToPage("/Login");

            LoadReports();
            return Page();
        }

        public IActionResult OnPostAdd()
        {
            var userId = HttpContext.Session.GetInt32("UserId");
            if (userId == null)
                return RedirectToPage("/Login");

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Execute(
                    "INSERT INTO yaka_reports (report_title, report_description, yaka_zone, report_date, attachment_url, status) VALUES (@ReportTitle, @ReportDescription, @YakaZone, @ReportDate, @AttachmentUrl, @Status)",
                    new { ReportTitle, ReportDescription, YakaZone, ReportDate, AttachmentUrl, Status });
            }
            catch (Exception ex)
            {
                ErrorMessage = ex.Message;
            }

            LoadReports();
            return Page();
        }

        public IActionResult OnPostUpdate()
        {
            var userId = HttpContext.Session.GetInt32("UserId");
            if (userId == null)
                return RedirectToPage("/Login");

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Execute(
                    "UPDATE yaka_reports SET report_title = @ReportTitle, report_description = @ReportDescription, yaka_zone = @YakaZone, report_date = @ReportDate, attachment_url = @AttachmentUrl, status = @Status WHERE id = @Id",
                    new { Id, ReportTitle, ReportDescription, YakaZone, ReportDate, AttachmentUrl, Status });
            }
            catch (Exception ex)
            {
                ErrorMessage = ex.Message;
            }

            LoadReports();
            return Page();
        }

        public IActionResult OnPostDelete(int id)
        {
            var userId = HttpContext.Session.GetInt32("UserId");
            if (userId == null)
                return RedirectToPage("/Login");

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Execute("DELETE FROM yaka_reports WHERE id = @Id", new { Id = id });
            }
            catch (Exception ex)
            {
                ErrorMessage = ex.Message;
            }

            LoadReports();
            return Page();
        }

        private void LoadReports()
        {
            using var connection = new MySqlConnection(_connectionString);
            YakaReports = connection.Query<YakaReport>("SELECT * FROM yaka_reports ORDER BY report_date DESC").ToList();
        }
    }

    public class YakaReport
    {
        public int Id { get; set; }
        public string ReportTitle { get; set; } = "";
        public string ReportDescription { get; set; } = "";
        public string YakaZone { get; set; } = "";
        public DateTime ReportDate { get; set; }
        public string AttachmentUrl { get; set; } = "";
        public string Status { get; set; } = "Pending";
    }
}