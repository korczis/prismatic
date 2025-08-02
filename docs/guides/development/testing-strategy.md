# Testing Strategy Guide

Comprehensive testing strategies and implementation patterns for building reliable, maintainable code in the Prismatic project.

## ⏱️ Time Estimates

📖 Reading time: 25 minutes | 🔧 Implementation time: 2-4 hours | 📊 Skill level: Intermediate

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [Development](README.md) > Testing Strategy

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to development guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔍 [Search Documentation](../../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Coding Standards](coding-standards.md) - Code quality and style guidelines that support testing
- [API Design Guidelines](api-design-guidelines.md) - API testing patterns and strategies
- [Error Handling & Logging](error-handling-logging.md) - Testing error scenarios and logging
- [Performance Optimization](../performance/performance-optimization.md) - Performance testing approaches
- [CI/CD Implementation](../workflow/ci-cd-implementation.md) - Automated testing in pipelines
- [Security Guidelines](../security/security-guidelines.md) - Security testing patterns
<!-- NAV_END -->

---

## Table of Contents

1. [Overview](#overview)
2. [Testing Philosophy](#testing-philosophy)
3. [Test Pyramid Strategy](#test-pyramid-strategy)
4. [Unit Testing with ExUnit](#unit-testing-with-exunit)
5. [Integration Testing](#integration-testing)
6. [End-to-End Testing](#end-to-end-testing)
7. [Testing LiveView Components](#testing-liveview-components)
8. [Database Testing](#database-testing)
9. [Mocking and Stubbing](#mocking-and-stubbing)
10. [Property-Based Testing](#property-based-testing)
11. [Performance Testing](#performance-testing)
12. [Test Organization](#test-organization)
13. [Code Coverage](#code-coverage)
14. [Testing Best Practices](#testing-best-practices)
15. [Common Anti-Patterns](#common-anti-patterns)
16. [Troubleshooting](#troubleshooting)

---

## Overview

Testing is fundamental to maintaining code quality, preventing regressions, and ensuring system reliability in the Prismatic project. This guide establishes comprehensive testing strategies that support rapid development while maintaining high confidence in code changes.

### Why This Matters

- **Quality Assurance**: Catch bugs before they reach production
- **Refactoring Safety**: Change code with confidence 
- **Documentation**: Tests serve as living examples of how code works
- **Team Collaboration**: Shared understanding of expected behavior
- **Debugging**: Isolate issues quickly with focused test coverage

### Scope

This guide covers testing strategies for:
- Phoenix web applications and APIs
- LiveView real-time interfaces
- Ecto database interactions
- Background job processing
- External service integrations
- Performance and load scenarios

---

## Testing Philosophy

### Quality Over Quantity

Focus on meaningful tests that provide value rather than pursuing 100% coverage metrics:

```elixir
# ✅ Good - Tests important business logic
defmodule Prismatic.Accounts.UserTest do
  test "creates user with valid email and hashed password" do
    attrs = %{email: "user@example.com", password: "secure123"}
    
    assert {:ok, user} = Accounts.create_user(attrs)
    assert user.email == "user@example.com"
    assert Argon2.verify_pass("secure123", user.password_hash)
    refute user.password_hash == "secure123"  # Ensures hashing occurred
  end
end

# ❌ Avoid - Testing framework behavior
test "ecto changeset validates required fields" do
  changeset = User.changeset(%User{}, %{})
  refute changeset.valid?  # This tests Ecto, not our logic
end
```

### Test-Driven Development (TDD)

When appropriate, use TDD to drive design decisions:

1. **Red**: Write a failing test that describes desired behavior
2. **Green**: Write minimal code to make the test pass
3. **Refactor**: Improve code while keeping tests green

### Fast Feedback Loops

Design tests for quick execution to enable frequent running:

```elixir
# ✅ Good - Fast, isolated unit test
defmodule Prismatic.Utils.EmailValidatorTest do
  use ExUnit.Case, async: true  # Runs in parallel
  
  alias Prismatic.Utils.EmailValidator
  
  test "validates email format" do
    assert EmailValidator.valid?("user@example.com")
    refute EmailValidator.valid?("invalid-email")
  end
end
```

---

## Test Pyramid Strategy

### Unit Tests (70%)

**Purpose**: Test individual functions and modules in isolation

**Characteristics**:
- Fast execution (< 1ms per test)
- No external dependencies
- High coverage of edge cases
- Run in parallel (`async: true`)

```elixir
defmodule Prismatic.Content.SlugGeneratorTest do
  use ExUnit.Case, async: true
  
  alias Prismatic.Content.SlugGenerator
  
  describe "generate/1" do
    test "converts title to URL-friendly slug" do
      assert SlugGenerator.generate("Hello World!") == "hello-world"
      assert SlugGenerator.generate("Special Chars: @#$%") == "special-chars"
    end
    
    test "handles unicode characters" do
      assert SlugGenerator.generate("Café & Résumé") == "cafe-resume"
    end
    
    test "truncates long titles" do
      long_title = String.duplicate("word ", 20)
      slug = SlugGenerator.generate(long_title)
      
      assert String.length(slug) <= 50
      refute String.ends_with?(slug, "-")  # No trailing dash
    end
  end
end
```

### Integration Tests (20%)

**Purpose**: Test interactions between system components

**Characteristics**:
- Test module boundaries and data flow
- Include database interactions
- Verify external service integrations
- Moderate execution time

```elixir
defmodule Prismatic.AccountsTest do
  use Prismatic.DataCase, async: true
  
  alias Prismatic.Accounts
  alias Prismatic.Repo
  
  describe "user registration flow" do
    test "creates user and sends welcome email" do
      # Test integration between Accounts context and email delivery
      attrs = %{
        email: "new@example.com",
        password: "secure123",
        name: "Test User"
      }
      
      assert {:ok, user} = Accounts.register_user(attrs)
      assert user.email == "new@example.com"
      assert Repo.get_by(Accounts.User, email: "new@example.com")
      
      # Verify email was queued (using test adapter)
      assert_email_sent(to: "new@example.com", subject: "Welcome to Prismatic")
    end
  end
end
```

### End-to-End Tests (10%)

**Purpose**: Test complete user workflows through the full stack

**Characteristics**:
- Test critical user journeys
- Include browser automation (if web interface)
- Verify system behavior from user perspective
- Slowest execution time

```elixir
defmodule PrismaticWeb.UserRegistrationE2ETest do
  use PrismaticWeb.ConnCase
  
  test "complete user registration journey", %{conn: conn} do
    # Test the full registration flow through Phoenix
    conn = post(conn, ~p"/users/register", %{
      "user" => %{
        "email" => "integration@example.com",
        "password" => "secure123",
        "password_confirmation" => "secure123"
      }
    })
    
    assert redirected_to(conn) == ~p"/users/profile"
    
    # Verify user exists in database
    user = Repo.get_by(Accounts.User, email: "integration@example.com")
    assert user
    assert user.confirmed_at  # Email confirmation flow completed
  end
end
```

---

## Unit Testing with ExUnit

### Test Structure

Use the **Arrange-Act-Assert** pattern for clear, readable tests:

```elixir
defmodule Prismatic.Orders.PricingTest do
  use ExUnit.Case, async: true
  
  alias Prismatic.Orders.Pricing
  
  describe "calculate_total/2" do
    test "applies discount to order total" do
      # Arrange
      items = [
        %{price: 1000, quantity: 2},  # $20.00
        %{price: 500, quantity: 1}    # $5.00
      ]
      discount_percent = 10
      
      # Act
      total = Pricing.calculate_total(items, discount_percent)
      
      # Assert
      assert total == 2250  # $22.50 after 10% discount
    end
    
    test "handles empty order" do
      assert Pricing.calculate_total([], 0) == 0
    end
    
    test "validates discount percentage bounds" do
      items = [%{price: 1000, quantity: 1}]
      
      assert_raise ArgumentError, fn ->
        Pricing.calculate_total(items, 101)  # > 100%
      end
      
      assert_raise ArgumentError, fn ->
        Pricing.calculate_total(items, -1)   # < 0%
      end
    end
  end
end
```

### Test Data Management

Use consistent patterns for test data:

```elixir
defmodule Prismatic.TestSupport.Fixtures do
  @moduledoc """
  Shared fixtures for consistent test data across the application.
  
  Related: [Database Testing](#database-testing)
  """
  
  def user_fixture(attrs \\ %{}) do
    valid_attrs = %{
      email: "test#{System.unique_integer()}@example.com",
      password: "secure123",
      name: "Test User"
    }
    
    attrs = Map.merge(valid_attrs, Enum.into(attrs, %{}))
    
    {:ok, user} = Prismatic.Accounts.create_user(attrs)
    user
  end
  
  def article_fixture(user, attrs \\ %{}) do
    valid_attrs = %{
      title: "Test Article #{System.unique_integer()}",
      content: "Test content for the article",
      status: :published
    }
    
    attrs = Map.merge(valid_attrs, Enum.into(attrs, %{}))
    
    {:ok, article} = Prismatic.Content.create_article(user, attrs)
    article
  end
end
```

### Parameterized Tests

Test multiple scenarios efficiently:

```elixir
defmodule Prismatic.Utils.ValidatorTest do
  use ExUnit.Case, async: true
  use ExUnitProperties  # For property-based testing
  
  alias Prismatic.Utils.Validator
  
  describe "email validation" do
    # Table-driven tests for multiple scenarios
    @valid_emails [
      "user@example.com",
      "test.email+tag@domain.co.uk",
      "user123@subdomain.example.org"
    ]
    
    @invalid_emails [
      "invalid-email",
      "@example.com",
      "user@",
      "user..double.dot@example.com"
    ]
    
    for email <- @valid_emails do
      test "accepts valid email: #{email}" do
        assert Validator.valid_email?(unquote(email))
      end
    end
    
    for email <- @invalid_emails do
      test "rejects invalid email: #{email}" do
        refute Validator.valid_email?(unquote(email))
      end
    end
  end
end
```

---

## Integration Testing

### Phoenix Controller Testing

Test HTTP endpoints and request/response cycles:

```elixir
defmodule PrismaticWeb.ArticleControllerTest do
  use PrismaticWeb.ConnCase, async: true
  
  import Prismatic.TestSupport.Fixtures
  
  setup %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end
  
  describe "POST /articles" do
    test "creates article with valid data", %{conn: conn, user: user} do
      article_params = %{
        "title" => "New Article",
        "content" => "Article content here",
        "tags" => ["elixir", "testing"]
      }
      
      conn = post(conn, ~p"/articles", article: article_params)
      
      assert %{id: article_id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/articles/#{article_id}"
      
      # Verify article was created in database
      article = Prismatic.Content.get_article!(article_id)
      assert article.title == "New Article"
      assert article.author_id == user.id
    end
    
    test "returns errors with invalid data", %{conn: conn} do
      conn = post(conn, ~p"/articles", article: %{title: ""})
      
      assert html_response(conn, 200) =~ "can&#39;t be blank"
    end
    
    test "requires authentication" do
      conn = build_conn()  # No logged-in user
      conn = post(conn, ~p"/articles", article: %{title: "Test"})
      
      assert redirected_to(conn) == ~p"/users/log_in"
    end
  end
  
  describe "GET /articles/:id" do
    test "shows article to authorized user", %{conn: conn, user: user} do
      article = article_fixture(user)
      
      conn = get(conn, ~p"/articles/#{article}")
      
      assert html_response(conn, 200) =~ article.title
    end
    
    test "returns 404 for non-existent article", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/articles/999999")
      end
    end
  end
end
```

### JSON API Testing

Test API endpoints with structured assertions:

```elixir
defmodule PrismaticWeb.Api.V1.ArticleControllerTest do
  use PrismaticWeb.ConnCase, async: true
  
  import Prismatic.TestSupport.Fixtures
  
  setup %{conn: conn} do
    user = user_fixture()
    conn = 
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{generate_token(user)}")
    
    %{conn: conn, user: user}
  end
  
  describe "GET /api/v1/articles" do
    test "returns paginated articles list", %{conn: conn, user: user} do
      # Create test articles
      articles = for i <- 1..5 do
        article_fixture(user, %{title: "Article #{i}"})
      end
      
      conn = get(conn, ~p"/api/v1/articles", %{page: 1, per_page: 3})
      
      assert %{
        "data" => data,
        "meta" => %{
          "total" => 5,
          "page" => 1,
          "per_page" => 3,
          "total_pages" => 2
        }
      } = json_response(conn, 200)
      
      assert length(data) == 3
      assert List.first(data)["title"] == "Article 5"  # Most recent first
    end
    
    test "filters articles by status", %{conn: conn, user: user} do
      article_fixture(user, %{status: :published})
      article_fixture(user, %{status: :draft})
      
      conn = get(conn, ~p"/api/v1/articles", %{status: "published"})
      
      response = json_response(conn, 200)
      assert length(response["data"]) == 1
      assert List.first(response["data"])["status"] == "published"
    end
  end
  
  describe "POST /api/v1/articles" do
    test "creates article with valid JSON", %{conn: conn} do
      article_attrs = %{
        title: "API Article",
        content: "Content via API",
        tags: ["api", "testing"]
      }
      
      conn = post(conn, ~p"/api/v1/articles", article: article_attrs)
      
      assert %{
        "id" => article_id,
        "title" => "API Article",
        "status" => "draft"
      } = json_response(conn, 201)
      
      # Verify in database
      article = Prismatic.Content.get_article!(article_id)
      assert article.title == "API Article"
    end
    
    test "returns validation errors for invalid data", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/articles", article: %{title: ""})
      
      assert %{
        "errors" => %{
          "title" => ["can't be blank"]
        }
      } = json_response(conn, 422)
    end
  end
end
```

---

## End-to-End Testing

### System Integration Tests

Test complete workflows across system boundaries:

```elixir
defmodule Prismatic.OrderProcessingE2ETest do
  use Prismatic.DataCase
  
  import Prismatic.TestSupport.Fixtures
  import Mox  # For mocking external services
  
  setup :verify_on_exit!
  
  test "complete order processing workflow" do
    # Arrange - Set up test data
    user = user_fixture()
    product = product_fixture(%{price: 2500, inventory: 10})
    
    # Mock external payment service
    expect(Prismatic.PaymentService.Mock, :charge_card, fn _amount, _card ->
      {:ok, %{transaction_id: "txn_123", status: "succeeded"}}
    end)
    
    # Mock inventory service
    expect(Prismatic.InventoryService.Mock, :reserve_items, fn _items ->
      {:ok, %{reservation_id: "res_456"}}
    end)
    
    # Act - Execute the complete workflow
    order_params = %{
      user_id: user.id,
      items: [%{product_id: product.id, quantity: 2}],
      payment_method: %{
        type: "card",
        token: "card_token_123"
      },
      shipping_address: %{
        street: "123 Test St",
        city: "Test City",
        postal_code: "12345"
      }
    }
    
    assert {:ok, order} = Prismatic.Orders.process_order(order_params)
    
    # Assert - Verify complete system state
    assert order.status == :confirmed
    assert order.total == 5000  # 2 * $25.00
    assert order.payment_status == :paid
    assert order.fulfillment_status == :processing
    
    # Verify side effects
    updated_product = Prismatic.Catalog.get_product!(product.id)
    assert updated_product.inventory == 8  # Reduced by 2
    
    # Verify async jobs were enqueued
    assert_enqueued(worker: Prismatic.Workers.OrderConfirmationEmail, 
                   args: %{"order_id" => order.id})
    assert_enqueued(worker: Prismatic.Workers.InventoryUpdate,
                   args: %{"product_id" => product.id, "quantity" => -2})
  end
  
  test "handles payment failure gracefully" do
    user = user_fixture()
    product = product_fixture(%{price: 1000, inventory: 5})
    
    # Mock payment failure
    expect(Prismatic.PaymentService.Mock, :charge_card, fn _amount, _card ->
      {:error, %{code: "card_declined", message: "Insufficient funds"}}
    end)
    
    order_params = %{
      user_id: user.id,
      items: [%{product_id: product.id, quantity: 1}],
      payment_method: %{type: "card", token: "declined_card"}
    }
    
    assert {:error, :payment_failed} = Prismatic.Orders.process_order(order_params)
    
    # Verify no side effects occurred
    updated_product = Prismatic.Catalog.get_product!(product.id)
    assert updated_product.inventory == 5  # Unchanged
    
    # Verify no jobs were enqueued
    refute_enqueued(worker: Prismatic.Workers.OrderConfirmationEmail)
  end
end
```

---

## Testing LiveView Components

### LiveView Integration Tests

Test real-time user interactions:

```elixir
defmodule PrismaticWeb.ArticleLive.IndexTest do
  use PrismaticWeb.ConnCase
  
  import Phoenix.LiveViewTest
  import Prismatic.TestSupport.Fixtures
  
  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end
  
  test "displays articles and allows filtering", %{conn: conn, user: user} do
    # Create test articles
    published_article = article_fixture(user, %{title: "Published", status: :published})
    draft_article = article_fixture(user, %{title: "Draft", status: :draft})
    
    # Mount the LiveView
    {:ok, live, html} = live(conn, ~p"/articles")
    
    # Verify initial render
    assert html =~ "Published"
    assert html =~ "Draft"
    
    # Test filtering by status
    live
    |> form("#filter-form", %{status: "published"})
    |> render_submit()
    
    # Verify filtered results
    assert render(live) =~ "Published"
    refute render(live) =~ "Draft"
    
    # Test clearing filter
    live
    |> element("#clear-filter")
    |> render_click()
    
    assert render(live) =~ "Published"
    assert render(live) =~ "Draft"
  end
  
  test "handles real-time updates when article is published", %{conn: conn, user: user} do
    draft_article = article_fixture(user, %{status: :draft})
    
    {:ok, live, _html} = live(conn, ~p"/articles?status=published")
    
    # Initially should not show draft article
    refute render(live) =~ draft_article.title
    
    # Simulate another user publishing the article
    {:ok, _updated} = Prismatic.Content.publish_article(draft_article)
    
    # Verify LiveView receives the real-time update
    assert render(live) =~ draft_article.title
  end
  
  test "validates form input and shows errors", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/articles/new")
    
    # Submit invalid form
    live
    |> form("#article-form", article: %{title: "", content: ""})
    |> render_submit()
    
    # Verify errors are displayed
    assert render(live) =~ "can&#39;t be blank"
    
    # Submit valid form
    live
    |> form("#article-form", article: %{
      title: "New Article",
      content: "Article content"
    })
    |> render_submit()
    
    # Verify redirect after successful creation
    assert_redirected(live, ~p"/articles")
  end
end
```

### Component Unit Tests

Test LiveView components in isolation:

```elixir
defmodule PrismaticWeb.Components.ArticleCardTest do
  use PrismaticWeb.ConnCase, async: true
  
  import Phoenix.LiveViewTest
  import Prismatic.TestSupport.Fixtures
  
  alias PrismaticWeb.Components.ArticleCard
  
  test "renders article information correctly" do
    user = user_fixture()
    article = article_fixture(user, %{
      title: "Test Article",
      content: "This is test content",
      published_at: ~U[2024-01-15 10:30:00Z]
    })
    
    html = render_component(ArticleCard, %{article: article})
    
    assert html =~ "Test Article"
    assert html =~ "Jan 15, 2024"
    assert html =~ user.name
  end
  
  test "shows edit button for article author" do
    user = user_fixture()
    article = article_fixture(user)
    
    # Render as the author
    html = render_component(ArticleCard, %{
      article: article,
      current_user: user
    })
    
    assert html =~ "Edit"
    
    # Render as different user
    other_user = user_fixture()
    html = render_component(ArticleCard, %{
      article: article,
      current_user: other_user
    })
    
    refute html =~ "Edit"
  end
end
```

---

## Database Testing

### Ecto.Sandbox Configuration

Configure test database for isolated, concurrent tests:

```elixir
# config/test.exs
config :prismatic, Prismatic.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "prismatic_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# test/support/data_case.ex
defmodule Prismatic.DataCase do
  use ExUnit.CaseTemplate
  
  using do
    quote do
      alias Prismatic.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Prismatic.DataCase
    end
  end
  
  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Prismatic.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
```

### Database Transaction Testing

Test database operations and rollbacks:

```elixir
defmodule Prismatic.Accounts.UserRegistrationTest do
  use Prismatic.DataCase, async: true
  
  alias Prismatic.Accounts
  alias Prismatic.Repo
  
  describe "register_user/1" do
    test "creates user and profile in transaction" do
      attrs = %{
        email: "test@example.com",
        password: "secure123",
        profile: %{
          name: "Test User",
          bio: "Test bio"
        }
      }
      
      assert {:ok, user} = Accounts.register_user(attrs)
      
      # Verify both user and profile were created
      user_with_profile = Repo.get!(Accounts.User, user.id) |> Repo.preload(:profile)
      assert user_with_profile.profile.name == "Test User"
    end
    
    test "rolls back transaction on profile creation failure" do
      # Mock profile validation to fail
      invalid_attrs = %{
        email: "test@example.com",
        password: "secure123",
        profile: %{
          name: "",  # Invalid - required field
          bio: String.duplicate("x", 1001)  # Invalid - too long
        }
      }
      
      assert {:error, :profile, changeset, _changes} = Accounts.register_user(invalid_attrs)
      
      # Verify no user was created due to transaction rollback
      assert Repo.get_by(Accounts.User, email: "test@example.com") == nil
    end
  end
  
  test "concurrent user creation with unique constraint" do
    # Test race condition handling
    attrs = %{email: "concurrent@example.com", password: "secure123"}
    
    tasks = for _i <- 1..3 do
      Task.async(fn -> Accounts.create_user(attrs) end)
    end
    
    results = Task.await_many(tasks)
    
    # Only one should succeed, others should fail with unique constraint
    successful = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))
    
    assert successful == 1
    assert failed == 2
  end
end
```

---

## Mocking and Stubbing

### Using Mox for Behaviour-Based Mocking

Define and test with clean boundaries:

```elixir
# Define behaviour for external service
defmodule Prismatic.EmailService do
  @callback send_email(to :: String.t(), subject :: String.t(), body :: String.t()) ::
    {:ok, String.t()} | {:error, String.t()}
end

# Production implementation
defmodule Prismatic.EmailService.Mailgun do
  @behaviour Prismatic.EmailService
  
  def send_email(to, subject, body) do
    # Real Mailgun API integration
  end
end

# Test mock
Mox.defmock(Prismatic.EmailService.Mock, for: Prismatic.EmailService)

# In test
defmodule Prismatic.NotificationsTest do
  use Prismatic.DataCase
  
  import Mox
  
  setup :verify_on_exit!
  
  test "sends welcome email to new user" do
    # Set up expectation
    expect(Prismatic.EmailService.Mock, :send_email, fn to, subject, body ->
      assert to == "newuser@example.com"
      assert subject =~ "Welcome"
      assert body =~ "Thanks for joining"
      {:ok, "message_id_123"}
    end)
    
    user = user_fixture(%{email: "newuser@example.com"})
    
    assert :ok = Prismatic.Notifications.send_welcome_email(user)
  end
  
  test "handles email service failure gracefully" do
    stub(Prismatic.EmailService.Mock, :send_email, fn _, _, _ ->
      {:error, "Service unavailable"}
    end)
    
    user = user_fixture()
    
    # Should not raise, but handle error appropriately
    assert {:error, :email_failed} = Prismatic.Notifications.send_welcome_email(user)
  end
end
```

### HTTP Client Mocking

Mock external API calls:

```elixir
defmodule Prismatic.ExternalApi.ClientTest do
  use ExUnit.Case, async: true
  
  import Mox
  
  setup :verify_on_exit!
  
  test "fetches user data from external API" do
    expect(HTTPoison.Mock, :get, fn url, headers, _opts ->
      assert url == "https://api.external.com/users/123"
      assert {"Authorization", "Bearer token123"} in headers
      
      {:ok, %HTTPoison.Response{
        status_code: 200,
        body: Jason.encode!(%{
          "id" => 123,
          "name" => "External User",
          "email" => "external@example.com"
        })
      }}
    end)
    
    client = Prismatic.ExternalApi.Client.new("token123")
    
    assert {:ok, user_data} = Prismatic.ExternalApi.Client.get_user(client, 123)
    assert user_data.name == "External User"
  end
  
  test "handles API rate limiting" do
    expect(HTTPoison.Mock, :get, fn _url, _headers, _opts ->
      {:ok, %HTTPoison.Response{
        status_code: 429,
        headers: [{"Retry-After", "60"}],
        body: "Rate limit exceeded"
      }}
    end)
    
    client = Prismatic.ExternalApi.Client.new("token123")
    
    assert {:error, :rate_limited, 60} = Prismatic.ExternalApi.Client.get_user(client, 123)
  end
end
```

---

## Property-Based Testing

### Using StreamData for Comprehensive Testing

Test properties that should hold for any valid input:

```elixir
defmodule Prismatic.Utils.StringUtilsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  
  alias Prismatic.Utils.StringUtils
  
  property "slug generation is reversible for basic strings" do
    check all original <- string(:alphanumeric, min_length: 1, max_length: 50) do
      slug = StringUtils.slugify(original)
      
      # Properties that should always hold
      assert is_binary(slug)
      assert String.length(slug) > 0
      assert String.match?(slug, ~r/^[a-z0-9\-]+$/)  # Only lowercase, numbers, dashes
      refute String.starts_with?(slug, "-")
      refute String.ends_with?(slug, "-")
    end
  end
  
  property "price calculations are always positive" do
    check all items <- list_of(map(%{
            price: positive_integer(),
            quantity: positive_integer()
          }), min_length: 1),
          discount <- integer(0..99) do
      
      total = Prismatic.Orders.calculate_total(items, discount)
      
      assert total >= 0
      assert is_integer(total)
      
      # If no discount, total should equal sum of price * quantity
      if discount == 0 do
        expected = Enum.sum(for %{price: p, quantity: q} <- items, do: p * q)
        assert total == expected
      end
    end
  end
  
  property "user validation accepts valid emails" do
    check all email <- email_generator() do
      changeset = Prismatic.Accounts.User.changeset(%Prismatic.Accounts.User{}, %{
        email: email,
        password: "validpassword123"
      })
      
      assert changeset.valid?
    end
  end
  
  # Custom generator for valid email addresses
  defp email_generator do
    gen all username <- string(:alphanumeric, min_length: 1, max_length: 20),
            domain <- string(:alphanumeric, min_length: 1, max_length: 15),
            tld <- member_of(["com", "org", "net", "edu"]) do
      "#{username}@#{domain}.#{tld}"
    end
  end
end
```

---

## Performance Testing

### Benchmark Critical Functions

Test performance characteristics of important code paths:

```elixir
defmodule Prismatic.Content.SearchTest do
  use Prismatic.DataCase
  
  alias Prismatic.Content.Search
  
  setup do
    # Create large dataset for performance testing
    user = user_fixture()
    
    articles = for i <- 1..1000 do
      article_fixture(user, %{
        title: "Article #{i}",
        content: "Content with keyword #{rem(i, 10)}",
        tags: ["tag#{rem(i, 5)}", "category#{rem(i, 3)}"]
      })
    end
    
    %{articles: articles}
  end
  
  @tag :performance
  test "search performance stays under threshold" do
    start_time = System.monotonic_time(:millisecond)
    
    results = Search.find_articles("keyword 5", limit: 20)
    
    end_time = System.monotonic_time(:millisecond)
    execution_time = end_time - start_time
    
    # Search should complete within 100ms
    assert execution_time < 100
    assert length(results) <= 20
  end
  
  @tag :performance
  test "memory usage remains stable during large operations" do
    memory_before = :erlang.memory(:total)
    
    # Perform memory-intensive operation
    for _i <- 1..100 do
      Search.find_articles("keyword", limit: 100)
    end
    
    # Force garbage collection
    :erlang.garbage_collect()
    
    memory_after = :erlang.memory(:total)
    memory_increase = memory_after - memory_before
    
    # Memory increase should be minimal (< 10MB)
    assert memory_increase < 10 * 1024 * 1024
  end
end
```

### Load Testing with Concurrent Operations

```elixir
defmodule Prismatic.Orders.ConcurrencyTest do
  use Prismatic.DataCase
  
  alias Prismatic.Orders
  
  @tag :load_test
  test "handles concurrent order processing" do
    user = user_fixture()
    product = product_fixture(%{inventory: 100})
    
    # Simulate 50 concurrent orders
    tasks = for i <- 1..50 do
      Task.async(fn ->
        Orders.create_order(%{
          user_id: user.id,
          items: [%{product_id: product.id, quantity: 1}]
        })
      end)
    end
    
    results = Task.await_many(tasks, 5000)  # 5 second timeout
    
    successful = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))
    
    # All orders should succeed without race conditions
    assert successful == 50
    assert failed == 0
    
    # Verify final inventory is correct
    updated_product = Prismatic.Catalog.get_product!(product.id)
    assert updated_product.inventory == 50  # 100 - 50
  end
end
```

---

## Test Organization

### Directory Structure

Organize tests to mirror application structure:

```
test/
├── test_helper.exs
├── support/
│   ├── data_case.ex
│   ├── conn_case.ex
│   ├── channel_case.ex
│   └── fixtures.ex
├── prismatic/
│   ├── accounts/
│   │   ├── user_test.exs
│   │   └── user_registration_test.exs
│   ├── content/
│   │   ├── article_test.exs
│   │   └── search_test.exs
│   └── orders/
│       ├── order_test.exs
│       └── pricing_test.exs
├── prismatic_web/
│   ├── controllers/
│   │   ├── article_controller_test.exs
│   │   └── user_controller_test.exs
│   ├── live/
│   │   ├── article_live_test.exs
│   │   └── dashboard_live_test.exs
│   └── components/
│       └── article_card_test.exs
└── integration/
    ├── user_registration_flow_test.exs
    └── order_processing_e2e_test.exs
```

### Test Configuration

Configure test environment for optimal performance and isolation:

```elixir
# test/test_helper.exs
ExUnit.start()

# Configure Ecto sandbox for database isolation
Ecto.Adapters.SQL.Sandbox.mode(Prismatic.Repo, :manual)

# Set up Mox for testing
Mox.defmock(Prismatic.EmailService.Mock, for: Prismatic.EmailService)
Application.put_env(:prismatic, :email_service, Prismatic.EmailService.Mock)
```

### Test Tags and Configuration

Use tags to organize and selectively run tests:

```elixir
# In test files
@tag :integration
test "complete user flow" do
  # Integration test
end

@tag :performance
test "search performance" do
  # Performance test
end

@tag :external_api
test "third party integration" do
  # Test requiring external service
end

# Run specific test types
# mix test --only integration
# mix test --exclude performance
# mix test --only external_api
```

---

## Code Coverage

### Coverage Configuration

Configure ExCoveralls for coverage tracking:

```elixir
# mix.exs
def project do
  [
    # ...
    test_coverage: [tool: ExCoveralls],
    preferred_cli_env: [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test
    ]
  ]
end

defp deps do
  [
    {:excoveralls, "~> 0.15", only: :test}
  ]
end
```

### Coverage Analysis

Focus on meaningful coverage metrics:

```bash
# Generate coverage report
mix coveralls.html

# View detailed coverage
mix coveralls.detail

# Coverage with specific threshold
mix coveralls --min-coverage 80
```

### Coverage Quality Guidelines

**Target Coverage Levels**:
- **Core Business Logic**: 90-95%
- **Phoenix Controllers**: 85-90%
- **Database Operations**: 85-90%
- **Utility Functions**: 95%+
- **Configuration/Setup**: 60-70%

**What Not to Test**:
- Generated Phoenix boilerplate
- Simple data structure definitions
- Configuration files
- Third-party library integrations (test your usage, not their code)

```elixir
# Focus coverage on business logic, not boilerplate
defmodule Prismatic.Orders.PricingTest do
  # ✅ Test core pricing logic
  test "applies tiered discount correctly" do
    # Test implementation
  end
  
  # ❌ Don't test Ecto schema definitions
  # test "user schema has correct fields" do
  #   # This tests Ecto, not our logic
  # end
end
```

---

## Testing Best Practices

### 1. Test Behavior, Not Implementation

```elixir
# ✅ Good - Tests behavior and outcome
test "user registration sends welcome email" do
  user_attrs = %{email: "test@example.com", password: "secure123"}
  
  assert {:ok, user} = Accounts.register_user(user_attrs)
  assert_email_sent(to: "test@example.com", subject: "Welcome")
end

# ❌ Avoid - Tests internal implementation details
test "user registration calls EmailService.send_email" do
  # This breaks when you change implementation
  expect(EmailService, :send_email, fn _, _ -> :ok end)
  # Test implementation
end
```

### 2. Keep Tests Independent

Each test should be able to run in isolation:

```elixir
# ✅ Good - Self-contained test
test "calculates shipping cost for heavy items" do
  # Create test data within the test
  item = %{weight: 15.5, dimensions: %{l: 30, w: 20, h: 10}}
  
  cost = ShippingCalculator.calculate_cost(item, "standard")
  
  assert cost == 1250  # $12.50
end

# ❌ Avoid - Depends on test execution order
test "setup shipping rules" do
  ShippingCalculator.add_rule(:heavy, weight: 15, cost: 1250)
end

test "uses heavy shipping rule" do  # Depends on previous test
  cost = ShippingCalculator.calculate_cost(%{weight: 16}, "standard")
  assert cost == 1250
end
```

### 3. Use Descriptive Test Names

Test names should clearly describe the scenario and expected outcome:

```elixir
# ✅ Good - Clear scenario and expectation
test "creates user account with hashed password when valid data provided" do
  # Test implementation
end

test "returns validation error when email format is invalid" do
  # Test implementation
end

test "prevents duplicate user registration with same email address" do
  # Test implementation
end

# ❌ Avoid - Vague or implementation-focused names
test "test user creation" do
  # What aspect of user creation?
end

test "changeset is invalid" do
  # Under what conditions?
end
```

### 4. Arrange-Act-Assert Pattern

Structure tests consistently for readability:

```elixir
test "applies bulk discount for large orders" do
  # Arrange - Set up test conditions
  items = [
    %{price: 1000, quantity: 25},  # $250
    %{price: 500, quantity: 30}    # $150
  ]
  customer = %{type: :premium, discount_tier: :gold}
  
  # Act - Execute the behavior being tested
  total = PricingEngine.calculate_total(items, customer)
  
  # Assert - Verify expected outcomes
  assert total == 32000  # $320 after 20% bulk + 5% premium discounts
end
```

### 5. Test Edge Cases and Error Conditions

Don't just test the happy path:

```elixir
describe "order processing" do
  test "processes valid order successfully" do
    # Happy path test
  end
  
  test "handles insufficient inventory gracefully" do
    product = product_fixture(%{inventory: 5})
    
    result = Orders.create_order(%{
      items: [%{product_id: product.id, quantity: 10}]
    })
    
    assert {:error, :insufficient_inventory} = result
  end
  
  test "validates order total is positive" do
    result = Orders.create_order(%{items: []})
    
    assert {:error, changeset} = result
    assert %{items: ["must have at least one item"]} = errors_on(changeset)
  end
  
  test "handles concurrent order processing without race conditions" do
    # Concurrency test
  end
end
```

### 6. Use Setup Blocks Wisely

Share common setup while keeping tests clear:

```elixir
defmodule Prismatic.AccountsTest do
  use Prismatic.DataCase, async: true
  
  describe "user authentication" do
    setup do
      user = user_fixture(%{
        email: "test@example.com",
        password: "secure123"
      })
      
      %{user: user}
    end
    
    test "authenticates with correct password", %{user: user} do
      assert {:ok, authenticated_user} = Accounts.authenticate(
        user.email,
        "secure123"
      )
      assert authenticated_user.id == user.id
    end
    
    test "rejects incorrect password", %{user: user} do
      assert {:error, :invalid_credentials} = Accounts.authenticate(
        user.email,
        "wrongpassword"
      )
    end
  end
end
```

---

## Common Anti-Patterns

### 1. Over-Mocking

```elixir
# ❌ Avoid - Mocking everything makes tests brittle
test "user registration" do
  expect(Repo.Mock, :insert, fn _ -> {:ok, %User{}} end)
  expect(EmailService.Mock, :send, fn _ -> :ok end)
  expect(Logger.Mock, :info, fn _ -> :ok end)
  expect(PubSub.Mock, :broadcast, fn _ -> :ok end)
  
  # Test tells us nothing about real behavior
end

# ✅ Better - Mock only external boundaries
test "user registration" do
  expect(EmailService.Mock, :send_welcome_email, fn _ -> :ok end)
  
  # Use real database and internal logic
  assert {:ok, user} = Accounts.register_user(valid_attrs)
  assert user.email == "test@example.com"
end
```

### 2. Testing Implementation Details

```elixir
# ❌ Avoid - Coupled to internal structure
test "user changeset has required fields" do
  changeset = User.changeset(%User{}, %{})
  assert changeset.required == [:email, :password]  # Internal detail
end

# ✅ Better - Test behavior and validation
test "requires email and password for user creation" do
  assert {:error, changeset} = Accounts.create_user(%{})
  
  assert %{
    email: ["can't be blank"],
    password: ["can't be blank"]
  } = errors_on(changeset)
end
```

### 3. Overly Complex Test Setup

```elixir
# ❌ Avoid - Complex, hard-to-understand setup
setup do
  org = insert(:organization)
  admin = insert(:user, role: :admin, organization: org)
  manager = insert(:user, role: :manager, organization: org)
  employee = insert(:user, role: :employee, organization: org)
  project = insert(:project, organization: org, owner: admin)
  task1 = insert(:task, project: project, assignee: employee)
  task2 = insert(:task, project: project, assignee: manager)
  
  %{org: org, admin: admin, manager: manager, employee: employee,
    project: project, tasks: [task1, task2]}
end

# ✅ Better - Minimal, focused setup per test
test "employee can view assigned tasks" do
  employee = user_fixture(%{role: :employee})
  task = task_fixture(%{assignee: employee})
  
  assert {:ok, tasks} = Tasks.list_for_user(employee)
  assert task in tasks
end
```

### 4. Shared Mutable State

```elixir
# ❌ Avoid - Tests affect each other
defmodule BadTestExample do
  @shared_data %{counter: 0}
  
  test "increments counter" do
    # Modifies shared state
    Process.put(:counter, (@shared_data.counter || 0) + 1)
    assert Process.get(:counter) == 1
  end
  
  test "counter starts at zero" do
    # Fails if previous test ran first
    assert Process.get(:counter, 0) == 0
  end
end

# ✅ Better - Isolated test data
test "increments user login count" do
  user = user_fixture(%{login_count: 5})
  
  {:ok, updated_user} = Accounts.record_login(user)
  
  assert updated_user.login_count == 6
end
```

---

## Troubleshooting

### Common Test Issues

#### Flaky Tests

**Problem**: Tests pass sometimes, fail other times

**Solutions**:
```elixir
# Use explicit waits instead of sleeps
test "processes async job" do
  BackgroundJob.perform_async(:send_email, email_id)
  
  # ❌ Avoid
  Process.sleep(100)  # Unreliable timing
  
  # ✅ Better - Wait for specific condition
  assert_async(fn ->
    email = Repo.get(Email, email_id)
    email.status == :sent
  end, timeout: 1000)
end

# Fix race conditions with proper synchronization
test "concurrent access to shared resource" do
  # Ensure proper isolation
  pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Repo, shared: false)
  
  # Test concurrent operations
  tasks = for _i <- 1..10 do
    Task.async(fn ->
      Ecto.Adapters.SQL.Sandbox.allow(Repo, pid, self())
      # Test operations
    end)
  end
  
  Task.await_many(tasks)
end
```

#### Slow Test Suite

**Problem**: Tests take too long to run

**Solutions**:
```elixir
# Use async: true for independent tests
defmodule FastTest do
  use ExUnit.Case, async: true  # Runs in parallel
  
  # No database operations, external calls, or shared state
end

# Optimize database operations
setup do
  # ❌ Slow - Multiple database roundtrips
  user = Repo.insert!(%User{email: "test@example.com"})
  profile = Repo.insert!(%Profile{user_id: user.id, name: "Test"})
  
  # ✅ Faster - Single transaction
  {:ok, %{user: user, profile: profile}} = Repo.transaction(fn ->
    user = Repo.insert!(%User{email: "test@example.com"})
    profile = Repo.insert!(%Profile{user_id: user.id, name: "Test"})
    %{user: user, profile: profile}
  end)
end

# Use factories efficiently
def user_fixture(attrs \\ %{}) do
  # Cache expensive operations
  default_attrs = %{
    email: "user#{System.unique_integer()}@example.com",
    password_hash: Argon2.hash_pwd_salt("password")  # Pre-computed
  }
  
  attrs = Map.merge(default_attrs, Enum.into(attrs, %{}))
  Repo.insert!(struct(User, attrs))
end
```

#### Memory Issues

**Problem**: Tests consume too much memory

**Solutions**:
```elixir
# Clean up large data structures
test "processes large dataset" do
  large_dataset = create_large_test_data()
  
  result = DataProcessor.process(large_dataset)
  
  # Explicitly clean up
  large_dataset = nil
  :erlang.garbage_collect()
  
  assert result.status == :completed
end

# Use streams for large data processing tests
test "processes files efficiently" do
  # Don't load entire file into memory
  result =
    "test/fixtures/large_file.csv"
    |> File.stream!()
    |> CSV.decode()
    |> DataProcessor.process_stream()
    |> Enum.count()
  
  assert result > 0
end
```

### Test Debugging

#### Debug Failing Tests

```elixir
test "complex calculation" do
  input = complex_test_data()
  
  # Add debugging output
  IO.inspect(input, label: "Input data")
  
  result = ComplexCalculator.calculate(input)
  
  IO.inspect(result, label: "Calculation result")
  
  # Use more specific assertions
  assert result.total >= 0, "Total should not be negative: #{result.total}"
  assert result.items |> length() == 3, "Expected 3 items, got #{length(result.items)}"
end
```

#### Isolate Test Issues

```elixir
# Run single test file
# mix test test/prismatic/accounts_test.exs

# Run single test
# mix test test/prismatic/accounts_test.exs:42

# Run with detailed output
# mix test --trace test/prismatic/accounts_test.exs

# Run with seed for reproducibility
# mix test --seed 123456
```

### Performance Debugging

```elixir
# Profile test execution
test "performance critical function" do
  :fprof.start()
  :fprof.trace([:start])
  
  # Code under test
  result = PerformanceCritical.expensive_operation(large_input)
  
  :fprof.trace([:stop])
  :fprof.profile()
  :fprof.analyse([dest: 'test_profile.txt'])
  
  assert result.success?
end

# Memory profiling
test "memory usage" do
  memory_before = :erlang.memory(:total)
  
  result = MemoryIntensive.process(large_data)
  
  :erlang.garbage_collect()
  memory_after = :erlang.memory(:total)
  
  memory_used = memory_after - memory_before
  
  # Assert memory usage is within acceptable bounds
  assert memory_used < 50 * 1024 * 1024  # 50MB
  assert result.processed_count > 0
end
```

---

## Related Documentation

- **[Coding Standards](coding-standards.md)** - Code quality standards that support effective testing
- **[API Design Guidelines](api-design-guidelines.md)** - API design patterns that facilitate testing
- **[Error Handling & Logging](error-handling-logging.md)** - Testing error scenarios and logging behavior
- **[Performance Optimization](../performance/performance-optimization.md)** - Performance testing and optimization strategies
- **[CI/CD Implementation](../workflow/ci-cd-implementation.md)** - Integrating tests into automated pipelines
- **[Security Guidelines](../security/security-guidelines.md)** - Security testing patterns and practices

---

**💡 Pro Tip**: Start with a few well-written unit tests for your core business logic, then gradually expand coverage. Focus on testing behavior that matters to your users rather than chasing coverage percentages. Remember: good tests make refactoring safer and development faster.