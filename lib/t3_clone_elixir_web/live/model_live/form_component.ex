defmodule T3CloneElixirWeb.ModelLive.FormComponent do
  use T3CloneElixirWeb, :live_component

  alias T3CloneElixir.Models

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage model records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="model-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:openrouter_name]} type="text" label="Openrouter name" />
        <.input field={@form[:allow_images]} type="checkbox" label="Allow images" />
        <.input field={@form[:allow_files]} type="checkbox" label="Allow files" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Model</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{model: model} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Models.change_model(model))
     end)}
  end

  @impl true
  def handle_event("validate", %{"model" => model_params}, socket) do
    changeset = Models.change_model(socket.assigns.model, model_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"model" => model_params}, socket) do
    save_model(socket, socket.assigns.action, model_params)
  end

  defp save_model(socket, :edit, model_params) do
    case Models.update_model(socket.assigns.model, model_params) do
      {:ok, model} ->
        notify_parent({:saved, model})

        {:noreply,
         socket
         |> put_flash(:info, "Model updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_model(socket, :new, model_params) do
    case Models.create_model(model_params) do
      {:ok, model} ->
        notify_parent({:saved, model})

        {:noreply,
         socket
         |> put_flash(:info, "Model created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
