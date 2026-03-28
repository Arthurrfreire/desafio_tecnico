defmodule WCoreWeb.UserLive.Login do
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
        <div class="mx-auto grid max-w-screen-2xl gap-6 lg:grid-cols-[minmax(0,1.15fr)_minmax(420px,0.85fr)]">
          <section class="overflow-hidden rounded-[2rem] border border-slate-200/70 bg-white/85 p-8 shadow-sm backdrop-blur-sm">
            <div class="max-w-2xl">
              <p class="text-xs font-semibold uppercase tracking-[0.32em] text-slate-500">
                Acesso operacional
              </p>
              <h1 class="mt-4 text-4xl font-semibold tracking-tight text-slate-950 sm:text-5xl">
                Sala de controle em tempo real
              </h1>
              <p class="mt-4 text-base leading-7 text-slate-600">
                Entre para acompanhar o estado atual dos sensores industriais, com leitura quente via ETS e persistencia consolidada em SQLite.
              </p>
            </div>

            <div class="mt-8 grid gap-4 md:grid-cols-3">
              <article class="rounded-[1.5rem] border border-slate-200 bg-slate-50/80 p-5">
                <p class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">
                  Leitura quente
                </p>
                <p class="mt-3 text-sm leading-6 text-slate-700">
                  O dashboard consulta o estado corrente direto da ETS para responder sem passar pelo banco em cada refresh.
                </p>
              </article>

              <article class="rounded-[1.5rem] border border-slate-200 bg-slate-50/80 p-5">
                <p class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">
                  Sinais criticos
                </p>
                <p class="mt-3 text-sm leading-6 text-slate-700">
                  Mudancas de status entram por PubSub e ficam destacadas visualmente para leitura rapida do operador.
                </p>
              </article>

              <article class="rounded-[1.5rem] border border-slate-200 bg-slate-50/80 p-5">
                <p class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">
                  Entrega local
                </p>
                <p class="mt-3 text-sm leading-6 text-slate-700">
                  Todo o fluxo roda localmente, sem dependencia de provedor externo de email ou banco remoto.
                </p>
              </article>
            </div>

            <div class="mt-8 rounded-[1.75rem] border border-slate-900/70 bg-slate-950 p-6 text-slate-100 shadow-sm">
              <p class="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">
                Fluxo de demo
              </p>
              <ol class="mt-4 space-y-3 text-sm leading-6 text-slate-300">
                <li>1. Solicite o magic link com o seu email.</li>
                <li>2. Abra a mailbox local em `/dev/mailbox` quando estiver em desenvolvimento.</li>
                <li>3. Acesse o painel para ver os sensores seeded e os heartbeats em tempo real.</li>
              </ol>
            </div>
          </section>

          <section class="rounded-[2rem] border border-slate-200/70 bg-white/92 p-6 shadow-sm backdrop-blur-sm sm:p-8">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.28em] text-slate-500">Log in</p>
              <h2 class="mt-3 text-3xl font-semibold tracking-tight text-slate-950">
                Entrar na plataforma
              </h2>
              <p class="mt-3 text-sm leading-6 text-slate-600">
                <%= if @current_scope do %>
                  You need to reauthenticate to perform sensitive actions on your account.
                <% else %>
                  Don't have an account?
                  <.link
                    navigate={~p"/users/register"}
                    class="font-semibold text-slate-950 underline decoration-slate-300 underline-offset-4 hover:decoration-slate-950"
                    phx-no-format
                  >
                    Sign up
                  </.link>
                  for an account now.
                <% end %>
              </p>
            </div>

            <div
              :if={local_mail_adapter?()}
              class="mt-6 rounded-[1.5rem] border border-sky-200 bg-sky-50/90 p-4 text-sm text-sky-950"
            >
              <div class="flex gap-3">
                <.icon name="hero-information-circle" class="mt-0.5 size-5 shrink-0 text-sky-700" />
                <div>
                  <p class="font-semibold">Ambiente local com mailbox interna</p>
                  <p class="mt-1 leading-6 text-sky-900/80">
                    To see sent emails, visit
                    <.link
                      href="http://127.0.0.1:4000/dev/mailbox"
                      class="font-semibold underline underline-offset-4"
                    >
                      the mailbox page
                    </.link>.
                  </p>
                </div>
              </div>
            </div>

            <div class="mt-8 space-y-6">
              <section class="rounded-[1.75rem] border border-slate-200 bg-slate-50/70 p-5">
                <div class="flex items-center justify-between gap-3">
                  <div>
                    <p class="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">
                      Acesso rapido
                    </p>
                    <h3 class="mt-2 text-lg font-semibold text-slate-950">Magic link</h3>
                  </div>
                  <span class="rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 text-xs font-semibold uppercase tracking-[0.16em] text-emerald-800">
                    Recomendado
                  </span>
                </div>

                <.form
                  :let={f}
                  for={@form}
                  id="login_form_magic"
                  action={~p"/users/log-in"}
                  phx-submit="submit_magic"
                  class="mt-5 space-y-4"
                >
                  <.input
                    readonly={!!@current_scope}
                    field={f[:email]}
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
                    class="inline-flex w-full items-center justify-center rounded-2xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white transition hover:bg-slate-800"
                  >
                    Log in with email <span aria-hidden="true" class="ml-2">→</span>
                  </button>
                </.form>
              </section>

              <div class="flex items-center gap-4">
                <div class="h-px flex-1 bg-slate-200" />
                <span class="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">or</span>
                <div class="h-px flex-1 bg-slate-200" />
              </div>

              <section class="rounded-[1.75rem] border border-slate-200 bg-white p-5">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-[0.2em] text-slate-500">
                    Acesso persistente
                  </p>
                  <h3 class="mt-2 text-lg font-semibold text-slate-950">Email e password</h3>
                </div>

                <.form
                  :let={f}
                  for={@form}
                  id="login_form_password"
                  action={~p"/users/log-in"}
                  phx-submit="submit_password"
                  phx-trigger-action={@trigger_submit}
                  class="mt-5 space-y-4"
                >
                  <.input
                    readonly={!!@current_scope}
                    field={f[:email]}
                    type="email"
                    label="Email"
                    autocomplete="username"
                    spellcheck="false"
                    required
                    class="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-slate-950 shadow-sm focus:border-slate-400 focus:outline-none"
                    error_class="border-rose-300 focus:border-rose-400"
                  />
                  <.input
                    field={@form[:password]}
                    type="password"
                    label="Password"
                    autocomplete="current-password"
                    spellcheck="false"
                    class="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-slate-950 shadow-sm focus:border-slate-400 focus:outline-none"
                    error_class="border-rose-300 focus:border-rose-400"
                  />
                  <button
                    type="submit"
                    name={@form[:remember_me].name}
                    value="true"
                    class="inline-flex w-full items-center justify-center rounded-2xl border border-slate-950 bg-slate-950 px-4 py-3 text-sm font-semibold text-white transition hover:bg-slate-800"
                  >
                    Log in and stay logged in <span aria-hidden="true" class="ml-2">→</span>
                  </button>
                  <button
                    type="submit"
                    class="inline-flex w-full items-center justify-center rounded-2xl border border-slate-200 bg-slate-100 px-4 py-3 text-sm font-semibold text-slate-700 transition hover:bg-slate-200"
                  >
                    Log in only this time
                  </button>
                </.form>
              </section>
            </div>
          </section>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:w_core, WCore.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
