# my-agent-frontend 树莓派部署

## 端口

| 环境 | 地址 |
|------|------|
| Pi 本机 | http://127.0.0.1:8086 |
| 公网（frp） | http://118.25.46.207:6086 |
| Interview Agent WS | ws://118.25.46.207:6085/ws |

## 首次部署（Pi）

```bash
sudo mkdir -p /opt/my-agent-frontend
sudo chown jenkins:jenkins /opt/my-agent-frontend
sudo -u jenkins git clone git@github.com:rockyshen/my-agent-frontend.git /opt/my-agent-frontend

# nginx
sudo cp /opt/my-agent-frontend/deploy/nginx/my-agent-frontend.conf /etc/nginx/sites-available/
sudo ln -sf /etc/nginx/sites-available/my-agent-frontend.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# frp（见 deploy/frpc-services.toml.example）
sudo systemctl restart frpc

# 构建
sudo -u jenkins bash /opt/my-agent-frontend/deploy/build-pi.sh

# Jenkins Job
sudo mkdir -p /var/lib/jenkins/jobs/my-agent-frontend
sudo cp /opt/my-agent-frontend/deploy/jenkins/job-config.xml /var/lib/jenkins/jobs/my-agent-frontend/config.xml
sudo chown -R jenkins:jenkins /var/lib/jenkins/jobs/my-agent-frontend
sudo systemctl restart jenkins
```

## GitHub Webhook

Payload URL: `http://118.25.46.207:8080/github-webhook/`（push 事件）

## 手动重新部署

```bash
sudo -u jenkins bash /opt/my-agent-frontend/deploy/build-pi.sh
```
