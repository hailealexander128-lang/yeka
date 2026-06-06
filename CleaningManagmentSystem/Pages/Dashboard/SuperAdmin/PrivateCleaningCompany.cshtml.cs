using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;
using Dapper;

namespace CleaningManagmentSystem.Pages.Dashboard.SuperAdmin
{
    public class PrivateCleaningCompanyModel : PageModel
    {
        private readonly string _connectionString;

        [BindProperty]
        public int Id { get; set; }

        [BindProperty]
        public string CompanyName { get; set; } = "";

        [BindProperty]
        public string ContactPerson { get; set; } = "";

        [BindProperty]
        public string Phone { get; set; } = "";

        [BindProperty]
        public string Email { get; set; } = "";

        [BindProperty]
        public string LicenseNumber { get; set; } = "";

        [BindProperty]
        public DateTime? ContractStartDate { get; set; }

        [BindProperty]
        public DateTime? ContractEndDate { get; set; }

        [BindProperty]
        public string Status { get; set; } = "Active";

        [BindProperty]
        public string ServicesProvided { get; set; } = "";

        [BindProperty]
        public string Address { get; set; } = "";

        [BindProperty]
        public string SearchQuery { get; set; } = "";

        public List<PrivateCompany> Companies { get; set; } = new();
        public string ErrorMessage { get; set; } = "";
        public string SuccessMessage { get; set; } = "";

        public PrivateCleaningCompanyModel(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection") ?? "";
        }

        public IActionResult OnGet()
        {
            Console.WriteLine("[PrivateCleaningCompany] OnGet called");
            
            var userName = HttpContext.Session.GetString("UserName");
            if (string.IsNullOrEmpty(userName))
            {
                Console.WriteLine("[PrivateCleaningCompany] No session, redirecting to Login");
                return RedirectToPage("/Login");
            }

            LoadCompanies();
            return Page();
        }

        public IActionResult OnPost()
        {
            Console.WriteLine($"[PrivateCleaningCompany] OnPost called with action");
            
            var userName = HttpContext.Session.GetString("UserName");
            if (string.IsNullOrEmpty(userName))
            {
                return RedirectToPage("/Login");
            }

            var action = Request.Form["action"];
            
            try
            {
                using var connection = new MySqlConnection(_connectionString);

                if (action == "create")
                {
                    CreateCompany(connection);
                    SuccessMessage = "Company created!";
                }
                else if (action == "update")
                {
                    UpdateCompany(connection);
                    SuccessMessage = "Company updated!";
                }
                else if (action == "delete")
                {
                    DeleteCompany(connection);
                    SuccessMessage = "Company deleted!";
                }
                else if (action == "toggle")
                {
                    ToggleStatus(connection);
                    SuccessMessage = "Status updated!";
                }
                else if (action == "create_user")
                {
                    CreateUserAccount(connection);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[PrivateCleaningCompany] Database error: {ex.Message}");
                ErrorMessage = "Database error occurred.";
            }

            LoadCompanies();
            return Page();
        }

        private void LoadCompanies()
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                string query = "SELECT * FROM private_cleaning_companies ORDER BY id DESC";
                
                if (!string.IsNullOrEmpty(SearchQuery))
                {
                    query = @"SELECT * FROM private_cleaning_companies 
                              WHERE company_name LIKE @Search OR contact_person LIKE @Search 
                              ORDER BY id DESC";
                    Companies = connection.Query<PrivateCompany>(query, new { Search = $"%{SearchQuery}%" }).ToList();
                }
                else
                {
                    Companies = connection.Query<PrivateCompany>(query).ToList();
                }
                
                Console.WriteLine($"[PrivateCleaningCompany] Loaded {Companies.Count} companies");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[PrivateCleaningCompany] Load error: {ex.Message}");
                ErrorMessage = "Error loading companies.";
            }
        }

        private void CreateCompany(MySqlConnection connection)
        {
            string query = @"INSERT INTO private_cleaning_companies 
                           (company_name, contact_person, phone, email, license_number, contract_start_date, contract_end_date, status, services_provided, address, created_at) 
                           VALUES (@CompanyName, @ContactPerson, @Phone, @Email, @LicenseNumber, @ContractStartDate, @ContractEndDate, @Status, @ServicesProvided, @Address, NOW())";
            
            connection.Execute(query, new { 
                CompanyName, 
                ContactPerson, 
                Phone, 
                Email, 
                LicenseNumber, 
                ContractStartDate, 
                ContractEndDate, 
                Status, 
                ServicesProvided,
                Address 
            });
            
            Console.WriteLine($"[PrivateCleaningCompany] Created: {CompanyName}");
        }

        private void UpdateCompany(MySqlConnection connection)
        {
            string query = @"UPDATE private_cleaning_companies 
                           SET company_name = @CompanyName, contact_person = @ContactPerson, phone = @Phone,
                               email = @Email, license_number = @LicenseNumber, contract_start_date = @ContractStartDate,
                               contract_end_date = @ContractEndDate, status = @Status, services_provided = @ServicesProvided,
                               address = @Address, updated_at = NOW()
                           WHERE id = @Id";
            
            connection.Execute(query, new { 
                CompanyName, 
                ContactPerson, 
                Phone, 
                Email, 
                LicenseNumber, 
                ContractStartDate, 
                ContractEndDate, 
                Status, 
                ServicesProvided, 
                Address,
                Id 
            });
            
            Console.WriteLine($"[PrivateCleaningCompany] Updated ID: {Id}");
        }

        private void DeleteCompany(MySqlConnection connection)
        {
            string query = "UPDATE private_cleaning_companies SET status = 'Inactive', deleted_at = NOW() WHERE id = @Id";
            connection.Execute(query, new { Id });
            Console.WriteLine($"[PrivateCleaningCompany] Deleted ID: {Id}");
        }

        private void ToggleStatus(MySqlConnection connection)
        {
            string newStatus = Status == "Active" ? "Inactive" : "Active";
            string query = "UPDATE private_cleaning_companies SET status = @Status, updated_at = NOW() WHERE id = @Id";
            connection.Execute(query, new { Status = newStatus, Id });
            Console.WriteLine($"[PrivateCleaningCompany] Toggled status for ID: {Id}");
        }

        private void CreateUserAccount(MySqlConnection connection)
        {
            // Get the company info
            var company = connection.QueryFirstOrDefault<PrivateCompany>(
                "SELECT * FROM private_cleaning_companies WHERE id = @Id", new { Id });
            if (company == null) { ErrorMessage = "Company not found."; return; }

            string userEmail    = Request.Form["user_email"].ToString().Trim();
            string userPassword = Request.Form["user_password"].ToString().Trim();
            string userName2    = Request.Form["user_name"].ToString().Trim();

            if (string.IsNullOrEmpty(userEmail) || string.IsNullOrEmpty(userPassword))
            { ErrorMessage = "Email and password are required."; return; }

            // Check email unique
            var existing = connection.QueryFirstOrDefault<int>(
                "SELECT COUNT(*) FROM users WHERE email = @Email", new { Email = userEmail });
            if (existing > 0) { ErrorMessage = $"Email {userEmail} already exists."; return; }

            connection.Execute(
                @"INSERT INTO users (name, email, password, role, phone, is_active, created_at, updated_at)
                  VALUES (@Name, @Email, @Password, 'PrivateCompanyRep', @Phone, 1, NOW(), NOW())",
                new {
                    Name     = string.IsNullOrEmpty(userName2) ? company.CompanyName + " Rep" : userName2,
                    Email    = userEmail,
                    Password = userPassword,
                    Phone    = company.Phone ?? ""
                });

            // Link user to company via company_user_id in private_cleaning_companies
            var newUserId = connection.QueryFirstOrDefault<int>("SELECT LAST_INSERT_ID()");
            try {
                connection.Execute(
                    "UPDATE private_cleaning_companies SET rep_user_id = @Uid WHERE id = @Id",
                    new { Uid = newUserId, Id });
            } catch { /* column may not exist yet — ignore */ }

            SuccessMessage = $"User account created: {userEmail} with role PrivateCompanyRep";
            Console.WriteLine($"[PrivateCleaningCompany] Created user account for company ID {Id}: {userEmail}");
        }
    }

    public class PrivateCompany
    {
        public int Id { get; set; }
        public string CompanyName { get; set; } = "";
        public string ContactPerson { get; set; } = "";
        public string Phone { get; set; } = "";
        public string Email { get; set; } = "";
        public string LicenseNumber { get; set; } = "";
        public DateTime? ContractStartDate { get; set; }
        public DateTime? ContractEndDate { get; set; }
        public string Status { get; set; } = "";
        public string ServicesProvided { get; set; } = "";
        public string Address { get; set; } = "";
        public DateTime? CreatedAt { get; set; }
    }
}