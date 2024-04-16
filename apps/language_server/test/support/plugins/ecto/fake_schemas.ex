defmodule ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.User do
  @moduledoc """
  Fake User schema.

  The docs.
  """

  def __schema__(:fields), do: [:id, :name, :email]
  def __schema__(:associations), do: [:assoc1, :assoc2]
  def __schema__(:type, :id), do: :id
  def __schema__(:type, :name), do: :string
  def __schema__(:type, :email), do: :string

  def __schema__(:association, :assoc1),
    do: %{related: FakeAssoc1, owner: __MODULE__, owner_key: :assoc1_id}

  def __schema__(:association, :assoc2),
    do: %{related: FakeAssoc2, owner: __MODULE__, owner_key: :assoc2_id}
end

defmodule ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Comment do
  @moduledoc """
  Fake Comment schema.
  """

  alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post

  def __schema__(:fields), do: [:content, :date]
  def __schema__(:associations), do: [:post]
  def __schema__(:type, :content), do: :string
  def __schema__(:type, :date), do: :date

  def __schema__(:association, :post),
    do: %{related: Post, owner: __MODULE__, owner_key: :post_id}
end

defmodule ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post do
  @moduledoc """
  Fake Post schema.
  """

  alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.User
  alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Comment

  def __schema__(:fields), do: [:id, :title, :text, :date, :user_id]
  def __schema__(:associations), do: [:user, :comments, :tags]
  def __schema__(:type, :id), do: :id
  def __schema__(:type, :user_id), do: :id
  def __schema__(:type, :title), do: :string
  def __schema__(:type, :text), do: :string
  def __schema__(:type, :date), do: :date

  def __schema__(:association, :user),
    do: %{related: User, related_key: :id, owner: __MODULE__, owner_key: :user_id}

  def __schema__(:association, :comments),
    do: %{related: Comment, related_key: :post_id, owner: __MODULE__, owner_key: :id}

  def __schema__(:association, :tags),
    do: %{related: Tag, owner: __MODULE__, owner_key: :id}
end

defmodule ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Tag do
  @moduledoc """
  Fake Tag schema.
  """

  alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post

  def __schema__(:fields), do: [:id, :name]
  def __schema__(:associations), do: [:posts]
  def __schema__(:type, :id), do: :id
  def __schema__(:type, :name), do: :string

  def __schema__(:association, :posts),
    do: %{related: Post, owner: __MODULE__, owner_key: :id}
end
