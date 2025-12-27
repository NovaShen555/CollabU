# CollabU 项目宝塔面板部署指南

本指南将指导你如何使用宝塔面板部署 CollabU 前后端分离项目。

## 1. 环境准备

在宝塔面板的【软件商店】中安装以下软件：

*   **Nginx**: 任意稳定版本 (如 1.22)
*   **MySQL**: 5.7 或 8.0
*   **Python 项目管理器**: 用于运行 Flask 后端 (推荐安装 Python 3.8+)
*   **PM2 管理器** (可选): 如果你想用 PM2 托管前端静态服务，不过通常 Nginx 足够。

## 2. 数据库配置

1.  进入【数据库】 -> 【添加数据库】。
2.  填写数据库名（例如 `collabu`），用户名和密码。
3.  点击【提交】。
4.  点击【管理】进入 phpMyAdmin (如果已安装) 或使用其他工具连接数据库。
    *   *注意：无需手动导入 SQL 文件，后续步骤会通过命令自动生成表结构。*

## 3. 后端部署 (Flask)

### 3.1 上传代码
1.  进入【文件】，在 `/www/wwwroot` 下创建一个目录，例如 `collabu_backend`。
2.  将本地 `backend` 文件夹内的所有文件上传到该目录。

### 3.2 配置 Python 环境
1.  打开【Python 项目管理器】。
2.  点击【添加 Python 项目】。
3.  **项目名称**: `collabu-api` (自定义)
4.  **路径**: 选择刚才上传的 `/www/wwwroot/collabu_backend`。
5.  **Python 版本**: 选择已安装的 Python 3.x。
6.  **框架**: `Flask`。
7.  **启动方式**: `Gunicorn`。
8.  **启动文件**: `run.py`。
9.  **端口**: 输入 `5000` (或其他你想要的端口，需在安全组放行)。
10. 勾选 **安装依赖** (会自动读取 `requirements.txt` 安装)。
11. 点击【确定】。

### 3.3 初始化数据库表结构 (新建表)
**重要步骤**：项目代码上传后，数据库是空的，需要执行命令来新建表结构。

1.  在【Python 项目管理器】列表中，找到刚才创建的项目。
2.  点击右侧的【终端】或【命令】按钮，进入项目环境的命令行。
3.  执行以下命令来新建表结构：
    ```bash
    flask db upgrade
    ```
    *解释：虽然命令叫 upgrade (升级)，但在新环境中，它的作用就是根据代码定义新建所有的数据库表。*
4.  如果显示 "Running upgrade..." 并成功结束，说明数据库表创建成功。

### 3.4 环境变量配置
1.  在项目根目录 `/www/wwwroot/collabu_backend` 下创建或编辑 `.env` 文件。
2.  填入生产环境配置：
    ```env
    FLASK_APP=run.py
    FLASK_ENV=production
    SECRET_KEY=你的强随机密钥
    JWT_SECRET_KEY=你的JWT密钥
    # 替换为你的宝塔数据库信息
    DATABASE_URL=mysql+pymysql://用户名:密码@127.0.0.1:3306/数据库名
    ```
3.  保存文件。
4.  在 Python 项目管理器中重启该项目。

## 4. 前端部署 (Vue3)

### 4.1 本地构建
1.  在本地 `frontend` 目录下打开终端。
2.  运行构建命令：
    ```bash
    npm run build
    ```
3.  构建完成后，会生成一个 `dist` 目录。

### 4.2 上传代码
1.  在宝塔【文件】中，在 `/www/wwwroot` 下创建前端目录，例如 `collabu_frontend`。
2.  将本地 `dist` 目录下的**所有文件**上传到该目录。

### 4.3 配置 Nginx 网站
1.  进入【网站】 -> 【添加站点】。
2.  **域名**: 填写你的域名或服务器 IP。
3.  **根目录**: 选择 `/www/wwwroot/collabu_frontend`。
4.  点击【提交】。

### 4.4 配置反向代理 (关键)
为了解决跨域问题并让前端能访问后端 API，需要配置 Nginx 反向代理。

1.  点击刚才创建的网站名称，进入【设置】。
2.  进入【配置文件】或【反向代理】(推荐直接改配置文件更灵活)。
3.  在 `server` 块中添加以下配置：

    ```nginx
    # 1. 前端路由支持 (防止刷新 404)
    location / {
      try_files $uri $uri/ /index.html;
    }

    # 2. 后端 API 代理
    location /api {
      proxy_pass http://127.0.0.1:5000; # 这里的端口要和 Python 项目端口一致
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # 3. Socket.IO 代理 (如果使用了 WebSocket)
    location /socket.io {
      proxy_pass http://127.0.0.1:5000;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header Host $host;
    }
    
    # 4. 静态资源代理 (头像等上传文件)
    location /uploads {
        alias /www/wwwroot/collabu_backend/app/uploads; # 指向后端的 uploads 目录
    }
    ```
4.  保存配置并重载 Nginx。

## 5. 验证

1.  访问你的域名或 IP。
2.  尝试登录、上传文件、使用 WebSocket 功能 (如聊天)。
3.  如果遇到问题：
    *   **后端报错**: 查看 Python 项目管理器中的【日志】。
    *   **前端报错**: 浏览器 F12 查看 Console 或 Network 面板。
    *   **数据库报错**: 检查 `.env` 中的数据库连接字符串是否正确。

## 常见问题

*   **上传文件失败**: 检查 `/www/wwwroot/collabu_backend/app/uploads` 目录是否有写入权限 (建议设为 755 或 777)。
*   **Socket 连接失败**: 确保 Nginx 配置了 `Upgrade` 和 `Connection` 头，且后端开启了 WebSocket 支持。
