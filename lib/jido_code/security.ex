defmodule JidoCode.Security do
  use Ash.Domain, otp_app: :jido_code, extensions: [AshAdmin.Domain, AshTypescript.Rpc]

  admin do
    show? true
  end

  typescript_rpc do
    resource JidoCode.Security.SecretRef
    resource JidoCode.Security.SecretLifecycleAudit
  end

  resources do
    resource JidoCode.Security.SecretRef
    resource JidoCode.Security.SecretLifecycleAudit
  end
end
