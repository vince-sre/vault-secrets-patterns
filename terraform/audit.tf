# Every request and response (with secrets HMAC'd) goes to the audit log,
# which is shipped to the SIEM by the node's log agent.
resource "vault_audit" "file" {
  type = "file"
  path = "file"

  options = {
    file_path = var.audit_file_path
    log_raw   = "false"
  }
}
