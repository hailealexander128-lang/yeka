using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;
using Dapper;

namespace CleaningManagmentSystem.Pages.Dashboard.SuperAdmin
{
    public class PostModel : PageModel
    {
        private readonly string _connectionString;

        [BindProperty]
        public int Id { get; set; }

        [BindProperty]
        public string Title { get; set; } = "";

        [BindProperty]
        public string Category { get; set; } = "";

        [BindProperty]
        public string PostContent { get; set; } = "";

        [BindProperty]
        public string Status { get; set; } = "Draft";

        [BindProperty]
        public string SearchQuery { get; set; } = "";

        [BindProperty]
        public int? TrainingId { get; set; }

        [BindProperty]
        public bool IsPinned { get; set; }

        [BindProperty]
        public string Priority { get; set; } = "Normal";

        [BindProperty]
        public string TargetRole { get; set; } = "All";

        public List<PostItem> Posts { get; set; } = new();
        
        public class TrainingListItem
        {
            public int Id { get; set; }
            public string Title { get; set; } = "";
        }
        public List<TrainingListItem> TrainingList { get; set; } = new();
        public string ErrorMessage { get; set; } = "";
        public string SuccessMessage { get; set; } = "";

        public PostModel(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection") ?? "";
        }

        public IActionResult OnGet()
        {
            Console.WriteLine("[Post] OnGet called");
            
            var userName = HttpContext.Session.GetString("UserName");
            if (string.IsNullOrEmpty(userName))
            {
                Console.WriteLine("[Post] No session, redirecting to Login");
                return RedirectToPage("/Login");
            }

            LoadPosts();
            LoadTrainings();
            return Page();
        }

        private void LoadTrainings()
        {
            using var connection = new MySqlConnection(_connectionString);
            TrainingList = connection.Query<TrainingListItem>("SELECT id, title FROM trainings").ToList();
        }

        public IActionResult OnPost()
        {
            Console.WriteLine($"[Post] OnPost called with action");
            
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
                    CreatePost(connection);
                    SuccessMessage = "Post created!";
                }
                else if (action == "update")
                {
                    UpdatePost(connection);
                    SuccessMessage = "Post updated!";
                }
                else if (action == "delete")
                {
                    DeletePost(connection);
                    SuccessMessage = "Post deleted!";
                }
                else if (action == "publish")
                {
                    PublishPost(connection);
                    SuccessMessage = "Post published!";
                }
                else if (action == "unpublish")
                {
                    UnpublishPost(connection);
                    SuccessMessage = "Post unpublished!";
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Post] Database error: {ex.Message}");
                ErrorMessage = "Database error occurred.";
            }

            LoadPosts();
            return Page();
        }

        [BindProperty(SupportsGet = true)]
        public string FilterCategory { get; set; } = "";

        private void LoadPosts()
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                string query = "SELECT * FROM posts WHERE 1=1";
                var parameters = new DynamicParameters();

                if (!string.IsNullOrEmpty(FilterCategory))
                {
                    query += " AND category = @Category";
                    parameters.Add("Category", FilterCategory);
                }

                if (!string.IsNullOrEmpty(SearchQuery))
                {
                    query += " AND (title LIKE @Search OR content LIKE @Search OR category LIKE @Search)";
                    parameters.Add("Search", $"%{SearchQuery}%");
                }

                query += " ORDER BY id DESC";
                Posts = connection.Query<PostItem>(query, parameters).ToList();
                
                Console.WriteLine($"[Post] Loaded {Posts.Count} posts");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Post] Load error: {ex.Message}");
                ErrorMessage = "Error loading posts.";
            }
        }

        private void CreatePost(MySqlConnection connection)
        {
            string query = @"INSERT INTO posts (title, category, content, status, training_id, is_pinned, priority, target_role, created_at) 
                           VALUES (@Title, @Category, @PostContent, @Status, @TrainingId, @IsPinned, @Priority, @TargetRole, NOW())";

            connection.Execute(query, new { 
                Title, 
                Category, 
                PostContent, 
                Status,
                TrainingId,
                IsPinned = IsPinned ? 1 : 0,
                Priority,
                TargetRole
            });

            Console.WriteLine($"[Post] Created: {Title}");
        }

        private void UpdatePost(MySqlConnection connection)
        {
            string query = @"UPDATE posts 
                           SET title = @Title, category = @Category, content = @PostContent, status = @Status, training_id = @TrainingId,
                               is_pinned = @IsPinned, priority = @Priority, target_role = @TargetRole, updated_at = NOW()
                           WHERE id = @Id";

            connection.Execute(query, new { 
                Title, 
                Category, 
                PostContent, 
                Status, 
                TrainingId,
                IsPinned = IsPinned ? 1 : 0,
                Priority,
                TargetRole,
                Id 
            });

            Console.WriteLine($"[Post] Updated ID: {Id}");
        }

        private void DeletePost(MySqlConnection connection)
        {
            string query = "UPDATE posts SET status = 'Deleted', deleted_at = NOW() WHERE id = @Id";
            connection.Execute(query, new { Id });
            Console.WriteLine($"[Post] Deleted ID: {Id}");
        }

        private void PublishPost(MySqlConnection connection)
        {
            string query = "UPDATE posts SET status = 'Published', published_at = NOW() WHERE id = @Id";
            connection.Execute(query, new { Id });
            Console.WriteLine($"[Post] Published ID: {Id}");
        }

        private void UnpublishPost(MySqlConnection connection)
        {
            string query = "UPDATE posts SET status = 'Draft', updated_at = NOW() WHERE id = @Id";
            connection.Execute(query, new { Id });
            Console.WriteLine($"[Post] Unpublished ID: {Id}");
        }
    }

    public class PostItem
    {
        public int Id { get; set; }
        public string Title { get; set; } = "";
        public string Category { get; set; } = "";
        public string Content { get; set; } = "";
        public string Status { get; set; } = "";
        public int? TrainingId { get; set; }
        public bool IsPinned { get; set; }
        public string Priority { get; set; } = "Normal";
        public string TargetRole { get; set; } = "All";
        public DateTime? CreatedAt { get; set; }
        public DateTime? PublishedAt { get; set; }
    }
}