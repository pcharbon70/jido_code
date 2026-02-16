defmodule JidoCode.Setup do
  use Ash.Domain, otp_app: :jido_code

  resources do
    resource JidoCode.Setup.SystemConfigRecord
  end
end
