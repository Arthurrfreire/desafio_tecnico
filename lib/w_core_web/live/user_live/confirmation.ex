defmodule WCoreWeb.UserLive.Confirmation do
  use WCoreWeb, :live_view

  alias WCore.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      main_class="px-0 py-0"
      container_class="max-w-none space-y-0"
    >
      <section class="auth-shell min-h-[calc(100vh-4.5rem)] px-4 py-8 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-3xl rounded-[2rem] border border-slate-200/70 bg-white/92 p-6 shadow-sm backdrop-blur-sm sm:p-8">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.28em] text-slate-500">
              Magic link
            </p>
            <h1 class="mt-3 text-3xl font-semibold tracking-tight text-slate-950">
              Welcome {@user.email}
            </h1>
            <p class="mt-3 text-sm leading-6 text-slate-600">
              <%= if @user.confirmed_at do %>
                Your account is already confirmed. You can use this link to log in securely.
              <% else %>
                This access confirms your account and signs you in using the standard Phoenix auth flow.
              <% end %>
            </p>
          </div>

          <.form
            :if={!@user.confirmed_at}
            for={@form}
            id="confirmation_form"
            phx-mounted={JS.focus_first()}
            phx-submit="submit"
            action={~p"/users/log-in?_action=confirmed"}
            phx-trigger-action={@trigger_submit}
            class="mt-8 space-y-3"
          >
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
            <.button
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with="Confirming..."
              class="inline-flex w-full items-center justify-center rounded-2xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white transition hover:bg-slate-800"
            >
              Confirm and stay logged in
            </.button>
            <.button
              phx-disable-with="Confirming..."
              class="inline-flex w-full items-center justify-center rounded-2xl border border-slate-200 bg-slate-100 px-4 py-3 text-sm font-semibold text-slate-700 transition hover:bg-slate-200"
            >
              Confirm and log in only this time
            </.button>
          </.form>

          <.form
            :if={@user.confirmed_at}
            for={@form}
            id="login_form"
            phx-submit="submit"
            phx-mounted={JS.focus_first()}
            action={~p"/users/log-in"}
            phx-trigger-action={@trigger_submit}
            class="mt-8 space-y-3"
          >
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
            <%= if @current_scope do %>
              <.button
                phx-disable-with="Logging in..."
                class="inline-flex w-full items-center justify-center rounded-2xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white transition hover:bg-slate-800"
              >
                Log in
              </.button>
            <% else %>
              <.button
                name={@form[:remember_me].name}
                value="true"
                phx-disable-with="Logging in..."
                class="inline-flex w-full items-center justify-center rounded-2xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white transition hover:bg-slate-800"
              >
                Keep me logged in on this device
              </.button>
              <.button
                phx-disable-with="Logging in..."
                class="inline-flex w-full items-center justify-center rounded-2xl border border-slate-200 bg-slate-100 px-4 py-3 text-sm font-semibold text-slate-700 transition hover:bg-slate-200"
              >
                Log me in only this time
              </.button>
            <% end %>
          </.form>

          <p
            :if={!@user.confirmed_at}
            class="mt-8 rounded-[1.5rem] border border-slate-200 bg-slate-50 px-4 py-4 text-sm leading-6 text-slate-600"
          >
            Tip: If you prefer passwords, you can enable them in the user settings.
          </p>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
