defmodule T3CloneElixirWeb.Router do
  use T3CloneElixirWeb, :router

  import T3CloneElixirWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {T3CloneElixirWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", T3CloneElixirWeb do
    pipe_through :browser


  end

  # Other scopes may use custom stacks.
  # scope "/api", T3CloneElixirWeb do
  #   pipe_through :api
  # end

  scope "/", T3CloneElixirWeb do
    pipe_through [:browser, :require_authenticated_user, :require_admin_user]

    live_session :require_admin_user,
      on_mount: [{T3CloneElixirWeb.UserAuth, :require_admin_user}] do
      live "/models", ModelLive.Index, :index
      live "/models/new", ModelLive.Index, :new
      live "/models/:id/edit", ModelLive.Index, :edit

      live "/models/:id", ModelLive.Show, :show
      live "/models/:id/show/edit", ModelLive.Show, :edit



      live "/chats_admin", ChatLive.Index, :index
      live "/chats_admin/new", ChatLive.Index, :new
      live "/chats_admin/:id/edit", ChatLive.Index, :edit

      live "/chats_admin/:id", ChatLive.Show, :show
      live "/chats_admin/:id/show/edit", ChatLive.Show, :edit



    end

  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:t3_clone_elixir, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: T3CloneElixirWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", T3CloneElixirWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{T3CloneElixirWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", T3CloneElixirWeb do
    pipe_through [:browser, :require_authenticated_user]
    get "/", PageController, :home

    live_session :require_authenticated_user,
      on_mount: [{T3CloneElixirWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email


      live "/chats", ChatLive.Home, :home
      live "/chats/:uuid", ChatLive.Home, :show
      live "/chats/:uuid/edit", ChatLive.Home, :edit
    end
  end

  scope "/", T3CloneElixirWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{T3CloneElixirWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  # Catch-all route for unmatched paths (404)
  scope "/", T3CloneElixirWeb do
    pipe_through :browser
    match :*, "/*path", FallbackController, :not_found
  end
end
