output "frontend_public_ip" {
  description = "Public IP of the frontend instance"
  value       = aws_instance.app.public_ip
}

output "frontend_url" {
  description = "URL to access the frontend"
  value       = "http://${aws_instance.app.public_ip}:3000"
}