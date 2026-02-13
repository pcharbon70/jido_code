defmodule JidoCode.Setup do
  use Ash.Domain, otp_app: :jido_code, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource JidoCode.Setup.SystemConfig
    resource JidoCode.Setup.Credential
    resource JidoCode.Setup.GithubAppInstallation
  end
end

