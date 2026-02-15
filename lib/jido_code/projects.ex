defmodule JidoCode.Projects do
  use Ash.Domain, otp_app: :jido_code, extensions: [AshAdmin.Domain, AshTypescript.Rpc]

  admin do
    show? true
  end

  typescript_rpc do
    resource JidoCode.Projects.Project
  end

  resources do
    resource JidoCode.Projects.Project
  end
end
