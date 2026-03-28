defmodule WCoreWeb.UserLive.Registration do
  use WCoreWeb, :live_view

  alias WCore.Accounts
  alias WCore.Accounts.User

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
        <div class="mx-auto grid max-w-screen-2xl gap-6 lg:grid-cols-[minmax(0,1.1fr)_minmax(420px,0.9fr)]">
          <section class="overflow-hidden rounded-[2rem] border border-slate-200/70 bg-white/85 p-8 shadow-sm backdrop-blur-sm">
            <div class="max-w-2xl">
              <p class="text-xs font-semibold uppercase tracking-[0.32em] text-slate-500">
                Onboarding tecnico
              </p>
              <h1 class="mt-4 text-4xl font-semibold tracking-tight text-slate-950 sm:text-5xl">
                Criar acesso ao W-Core
              </h1>
              <p class="mt-4 text-base leading-7 text-slate-600">
                O cadastro segue o fluxo do `phx.gen.auth` com link de acesso por email. Em desenvolvimento, a entrega do email fica toda dentro da mailbox local do Phoenix.
              </p>
            </div>

            <div class="mt-8 grid gap-4 md:grid-cols-2">
              <article class="rounded-[1.5rem] border border-slate-200 bg-slate-50/80 p-5">
                <p class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">
                  Sem dependencia externa
                </p>
                <p class="mt-3 text-sm leading-6 text-slate-700">
                  O fluxo continua totalmente local para facilitar setup, demo e explicacao arquitetural.
                </p>
              </article>

              <article class="rounded-[1.5rem] border border-slate-200 bg-slate-50/80 p-5">
                <p class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">
                  Auth gerado
                </p>
                <p class="mt-3 text-sm leading-6 text-slate-700">
                  A autenticacao foi mantida fiel ao scaffold do Phoenix, sem reinventar o fluxo de sessao.
                </p>
              </article>
            </div>
          </section>

          <section class="rounded-[2rem] border border-slate-200/70 bg-white/92 p-6 shadow-sm backdrop-blur-sm sm:p-8">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.28em] text-slate-500">Register</p>
              <h2 class="mt-3 text-3xl font-semibold tracking-tight text-slate-950">
                Register for an account
              </h2>
              <p class="mt-3 text-sm leading-6 text-slate-600">
                Already registered?
                <.link
                  navigate={~p"/users/log-in"}
                  class="font-semibold text-slate-950 underline decoration-slate-300 underline-offset-4 hover:decoration-slate-950"
                >
                  Log in
                </.link>
                to your account now.
              </p>
            </div>

            <div class="mt-8 rounded-[1.75rem] border border-slate-200 bg-slate-50/70 p-5">
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">
                Criacao de acesso
              </p>
              <.form
                for={@form}
                id="registration_form"
                phx-submit="save"
                phx-change="validate"
                class="mt-5 space-y-4"
              >
                <.input
                  field={@form[:email]}
                  type="email"
                  label="Email"
                  autocomplete="username"
                  spellcheck="false"
                  required
                  class="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-slate-950 shadow-sm focus:border-slate-400 focus:outline-none"
                  error_class="border-rose-300 focus:border-rose-400"
                  phx-mounted={JS.focus()}
                />

                <button
                  type="submit"
                  phx-disable-with="Creating account..."
                  class="inline-flex w-full items-center justify-center rounded-2xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white transition hover:bg-slate-800"
                >
                  Create an account
                </button>
              </.form>
            </div>
          </section>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: WCoreWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "A sign-in link was generated for #{user.email}. In development, open http://127.0.0.1:4000/dev/mailbox to access it."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
