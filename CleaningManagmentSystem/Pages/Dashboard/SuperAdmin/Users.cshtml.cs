using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;
using Dapper;
using CleaningManagmentSystem.Models;

namespace CleaningManagmentSystem.Pages.Dashboard.SuperAdmin
{
    public class UsersModel : PageModel
    {
        private readonly string _connectionString;

        [BindProperty]
        public int UserId { get; set; }

        [BindProperty]
        public string Name { get; set; } = "";

        [BindProperty]
        public string Email { get; set; } = "";

        [BindProperty]
        public string Password { get; set; } = "";

        [BindProperty]
        public string Role { get; set; } = "";

        [BindProperty]
        public string Phone { get; set; } = "";

        [BindProperty]
        public string Address { get; set; } = "";

        [BindProperty]
        public bool IsActive { get; set; } = true;

        [BindProperty]
        public string SearchQuery { get; set; } = "";

        public List<CleaningManagmentSystem.Models.User> UsersList { get; set; } = new();
        public string ErrorMessage { get; set; } = "";
        public string SuccessMessage { get; set; } = "";

        public UsersModel(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection") ?? "";
        }

        public IActionResult OnGet()
        {
            Console.WriteLine("[Users] OnGet called");
            
            var userName = HttpContext.Session.GetString("UserName");
            if (string.IsNullOrEmpty(userName))
            {
                Console.WriteLine("[Users] No session, redirecting to Login");
                return RedirectToPage("/Login");
            }

            LoadUsers();
            return Page();
        }

        public IActionResult OnPost()
        {
            Console.WriteLine($"[Users] OnPost called with action");
            
            var userName = HttpContext.Session.GetString("UserName");
            if (string.IsNullOrEmpty(userName))
            {
                return RedirectToPage("/Login");
            }

            var action = Request.Form["action"];
            Console.WriteLine($"[Users] Form values - Action: '{action}', UserId: {UserId}, Name: '{Name}', Email: '{Email}', Role: '{Role}'");
            
            if (string.IsNullOrEmpty(action))
            {
                ErrorMessage = "No action specified.";
                LoadUsers();
                return Page();
            }
            
            try
            {
                using var connection = new MySqlConnection(_connectionString);

                if (action == "create")
                {
                    CreateUser(connection);
                    SuccessMessage = "User created successfully!";
                }
                else if (action == "update")
                {
                    UpdateUser(connection);
                    SuccessMessage = "User updated successfully!";
                }
                else if (action == "delete")
                {
                    DeleteUser(connection);
                    SuccessMessage = "User deleted successfully!";
                }
                else if (action == "toggle")
                {
                    ToggleUserStatus(connection);
                    SuccessMessage = "User status updated!";
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Users] Database error: {ex.Message}");
                ErrorMessage = "Database error occurred. Please try again.";
            }

            LoadUsers();
            return Page();
        }

        private void LoadUsers()
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                string query = "SELECT * FROM users ORDER BY id DESC";
                
                if (!string.IsNullOrEmpty(SearchQuery))
                {
                    query = @"SELECT * FROM users 
                              WHERE name LIKE @Search OR email LIKE @Search OR phone LIKE @Search 
                              ORDER BY id DESC";
                    UsersList = connection.Query<CleaningManagmentSystem.Models.User>(query, new { Search = $"%{SearchQuery}%" }).ToList();
                }
                else
                {
                    UsersList = connection.Query<CleaningManagmentSystem.Models.User>(query).ToList();
                }
                
                Console.WriteLine($"[Users] Loaded {UsersList.Count} users");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Users] Load error: {ex.Message}");
                ErrorMessage = "Error loading users.";
            }
        }

        private void CreateUser(MySqlConnection connection)
        {
            string query = @"INSERT INTO users (name, email, password, role, phone, address, is_active, created_at) 
                           VALUES (@Name, @Email, @Password, @Role, @Phone, @Address, @IsActive, NOW())";
            
            connection.Execute(query, new { 
                Name, 
                Email, 
                Password, 
                Role, 
                Phone, 
                Address, 
                IsActive 
            });
            
            Console.WriteLine($"[Users] Created user: {Name}");
        }

        private void UpdateUser(MySqlConnection connection)
        {
            string query = @"UPDATE users 
                           SET name = @Name, email = @Email, role = @Role, 
                               phone = @Phone, address = @Address, is_active = @IsActive, updated_at = NOW()
                           WHERE id = @UserId";
            
            connection.Execute(query, new { 
                Name, 
                Email, 
                Role, 
                Phone, 
                Address, 
                IsActive, 
                UserId 
            });
            
            Console.WriteLine($"[Users] Updated user ID: {UserId}");
        }

        private void DeleteUser(MySqlConnection connection)
        {
            string query = "UPDATE users SET is_active = 0, deleted_at = NOW() WHERE id = @UserId";
            connection.Execute(query, new { UserId });
            Console.WriteLine($"[Users] Soft-deleted user ID: {UserId}");
        }

        private void ToggleUserStatus(MySqlConnection connection)
        {
            string query = "UPDATE users SET is_active = NOT is_active, updated_at = NOW() WHERE id = @UserId";
            connection.Execute(query, new { UserId });
            Console.WriteLine($"[Users] Toggled status for user ID: {UserId}");
        }
    }
}
