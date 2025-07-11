locals {
  # Define all SSM parameters with their paths
  ssm_parameters = {
    kms_admin_api_key                             = "/hyperswitch/admin-api-key"
    kms_recon_admin_api_key                       = "/hyperswitch/dummy-val"
    kms_jwt_secret                                = "/hyperswitch/jwt-secret"
    kms_encrypted_db_pass                         = "/hyperswitch/db-pass"
    kms_encrypted_master_key                      = "/hyperswitch/master-key"
    kms_jwekey_locker_identifier1                 = "/hyperswitch/dummy-val"
    kms_jwekey_locker_identifier2                 = "/hyperswitch/dummy-val"
    kms_jwekey_locker_encryption_key1             = "/hyperswitch/dummy-val"
    kms_jwekey_locker_encryption_key2             = "/hyperswitch/dummy-val"
    kms_jwekey_locker_decryption_key1             = "/hyperswitch/dummy-val"
    kms_jwekey_locker_decryption_key2             = "/hyperswitch/dummy-val"
    kms_jwekey_vault_encryption_key               = "/hyperswitch/locker-public-key"
    kms_jwekey_vault_private_key                  = "/hyperswitch/tenant-private-key"
    kms_jwekey_tunnel_private_key                 = "/hyperswitch/dummy-val"
    kms_jwekey_rust_locker_encryption_key         = "/hyperswitch/dummy-val"
    kms_connector_onboarding_paypal_client_id     = "/hyperswitch/dummy-val"
    kms_connector_onboarding_paypal_client_secret = "/hyperswitch/dummy-val"
    kms_connector_onboarding_paypal_partner_id    = "/hyperswitch/dummy-val"
    kms_forex_api_key                             = "/hyperswitch/dummy-val"
    kms_forex_fallback_api_key                    = "/hyperswitch/dummy-val"
    apple_pay_ppc                                 = "/hyperswitch/dummy-val"
    apple_pay_ppc_key                             = "/hyperswitch/dummy-val"
    apple_pay_merchant_conf_merchant_cert         = "/hyperswitch/dummy-val"
    apple_pay_merchant_conf_merchant_cert_key     = "/hyperswitch/dummy-val"
    apple_pay_merchant_conf_merchant_id           = "/hyperswitch/dummy-val"
    pm_auth_key                                   = "/hyperswitch/dummy-val"
    api_hash_key                                  = "/hyperswitch/kms-encrypted-api-hash-key"
    kms_encrypted_api_hash_key                    = "/hyperswitch/kms-encrypted-api-hash-key"
    encryption_key                                = "/hyperswitch/dummy-val"
    google_pay_root_signing_keys                  = "/hyperswitch/google-pay-root-signing-keys"
    paze_private_key                              = "/hyperswitch/paze-private-key"
    paze_private_key_passphrase                   = "/hyperswitch/paze-private-key-passphrase"
  }
}

# Fetch all parameters dynamically
data "aws_ssm_parameter" "all" {
  for_each = local.ssm_parameters

  name       = each.value
  depends_on = [aws_lambda_invocation.kms_encrypt]
}
