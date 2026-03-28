defmodule WCoreWeb.UserLive.Settings do
  use WCoreWeb, :live_view

  on_mount {WCoreWeb.UserAuth, :require_sudo_mode}

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
        <div class="mx-auto grid max-w-screen-2xl gap-6 lg:grid-cols-[minmax(0,1.05fr)_minmax(460px,0.95fr)]">
          <section class="overflow-hidden rounded-[2rem] border border-slate-200/70 bg-white/85 p-8 shadow-sm backdrop-blur-sm">
            <div class="max-w-2xl">
              <p class="text-xs font-semibold uppercase tracking-[0.32em] text-slate-500">
                Account settings
              </p>
              <h1 class="mt-4 text-4xl font-semibold tracking-tight text-slate-950 sm:text-5xl">
                Gerencie o acesso da sua conta
              </h1>
              <p class="mt-4 text-base leading-7 text-slate-600">
                Esta área mantém o fluxo do `phx.gen.auth` para alteração de email e password, sem adicionar regras extras fora do scaffold do Phoenix.
              </p>
            </div>

            <div class="mt-8 grid gap-4 md:grid-cols-3">
              <article class="rounded-[1.5rem] border border-slate-200 bg-slate-50/80 p-5">
                <p class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">
                  Reautenticação
                </p>
                <p class="mt-3 text-sm leading-6 text-slate-700">
                  A página exige sudo mode para operações sensíveis, exatamente como o gerador oficial recomenda.
                </p>
              </article>

              <article class="rounded-[1.5rem] border border-slate-200 bg-slate-50/80 p-5">
                <p class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">
                  Alteração de email
                </p>
                <p class="mt-3 text-sm leading-6 text-slate-700">
                  A troca do email continua sendo confirmada por link enviado para o novo endereço.
                </p>
              </article>

              <article class="rounded-[1.5rem] border border-slate-200 bg-slate-50/80 p-5">
                <p class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">
                  Segurança
                </p>
                <p class="mt-3 text-sm leading-6 text-slate-700">
                  A troca de password renova a sessão e preserva o comportamento esperado dos testes do scaffold.
                </p>
              </article>
            </div>

            <div class="mt-8 rounded-[1.75rem] border border-slate-900/70 bg-slate-950 p-6 text-slate-100 shadow-sm">
              <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">
                Conta ativa
              </p>
              <p class="mt-4 text-lg font-medium break-all">{@current_email}</p>
              <p class="mt-3 text-sm leading-6 text-slate-300">
                Use esta tela para demonstrar que o fluxo de autenticação continua completo mesmo em uma aplicação focada em telemetria.
              </p>
            </div>
          </section>

          <section class="space-y-6">
            <section class="rounded-[2rem] border border-slate-200/70 bg-white/92 p-6 shadow-sm backdrop-blur-sm sm:p-8">
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.28em] text-slate-500">
                  Email
                </p>
                <h2 class="mt-3 text-2xl font-semibold tracking-tight text-slate-950">
                  Update account email
                </h2>
                <p class="mt-3 text-sm leading-6 text-slate-600">
                  Manage your account email address and keep the login flow aligned with the local mailbox preview.
                </p>
              </div>

              <.form
                for={@email_form}
                id="email_form"
                phx-submit="update_email"
                phx-change="validate_email"
                class="mt-6 space-y-4"
              >
                <.input
                  field={@email_form[:email]}
                  type="email"
                  label="Email"
                  autocomplete="username"
                  spellcheck="false"
                  required
                  class="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-slate-950 shadow-sm focus:border-slate-400 focus:outline-none"
                  error_class="border-rose-300 focus:border-rose-400"
                />
                <button
                  type="submit"
                  phx-disable-with="Changing..."
                  class="inline-flex w-full items-center justify-center rounded-2xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white transition hover:bg-slate-800"
                >
                  Change Email
                </button>
              </.form>
            </section>

            <section class="rounded-[2rem] border border-slate-200/70 bg-white/92 p-6 shadow-sm backdrop-blur-sm sm:p-8">
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.28em] text-slate-500">
                  Password
                </p>
                <h2 class="mt-3 text-2xl font-semibold tracking-tight text-slate-950">
                  Update password
                </h2>
                <p class="mt-3 text-sm leading-6 text-slate-600">
                  Save a new password and keep the same Phoenix-authenticated session flow after the update.
                </p>
              </div>

              <.form
                for={@password_form}
                id="password_form"
                action={~p"/users/update-password"}
                method="post"
                phx-change="validate_password"
                phx-submit="update_password"
                phx-trigger-action={@trigger_submit}
                class="mt-6 space-y-4"
              >
                <input
                  name={@password_form[:email].name}
                  type="hidden"
                  id="hidden_user_email"
                  spellcheck="false"
                  value={@current_email}
                />
                <.input
                  field={@password_form[:password]}
                  type="password"
                  label="New password"
                  autocomplete="new-password"
                  spellcheck="false"
                  required
                  class="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-slate-950 shadow-sm focus:border-slate-400 focus:outline-none"
                  error_class="border-rose-300 focus:border-rose-400"
                />
                <.input
                  field={@password_form[:password_confirmation]}
                  type="password"
                  label="Confirm new password"
                  autocomplete="new-password"
                  spellcheck="false"
                  class="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-slate-950 shadow-sm focus:border-slate-400 focus:outline-none"
                  error_class="border-rose-300 focus:border-rose-400"
                />
                <button
                  type="submit"
                  phx-disable-with="Saving..."
                  class="inline-flex w-full items-center justify-center rounded-2xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white transition hover:bg-slate-800"
                >
                  Save Password
                </button>
              </.form>
            </section>
          </section>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
