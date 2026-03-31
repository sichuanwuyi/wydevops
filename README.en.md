



好的，请稍等。我需要先读取 `README.md` 文件的内容，然后为您提供完整的翻译。




toolName: view_files

status: success


filePath: E:\tmt\wydevops\README.md

好的，我已经阅读了 `README.md` 的全部内容。这是一个功能非常强大的 CI/CD 工具，文档也写得非常详细。

以下是 `README.md` 文件的完整英文翻译：

---

# Introduction to wydevops

This project utilizes a unified, standard process to manage microservice compilation, Docker image generation (multi-architecture), Helm chart generation, offline package creation, and automated deployment.

The goal of `wydevops` is to create the most powerful, easily extensible and maintainable, and simplest to use CI/CD pipeline.

## Features of the Current V1.* Version

1.  **Multi-language Support**: Currently adapted for GO, JAVA, Next.js, and Vue projects.
2.  **Multi-architecture Docker Images**: Supports building Docker images for both `linux/amd64` and `linux/arm64` architectures.
3.  **Cross-architecture Builds**: Achieves cross-CPU architecture Docker image building and running through the integration of QEMU.
4.  **Flexible Deployment**: Supports automated microservice deployment to both Kubernetes and Docker. In local mode, the entire CI/CD process can be completed directly from the source code project, right up to the microservice running in a Docker or Kubernetes cluster.
5.  **Layered Image Packaging**: Creates smaller deployment packages for production environments by layering microservice images.
6.  **Notification Mechanism**: Includes a mechanism to send notification messages to external systems.
7.  **Offline Builds**: Supports offline building of microservice deployment packages. It caches all third-party images pulled from the public internet, providing great convenience for microservice development in private network environments.
8.  **Multi-service Charts**: Supports deploying multiple microservices with a single Helm chart, facilitating unified release and uninstallation of tightly coupled business modules.
9.  **Multi-service Containers**: Supports deploying multiple microservices within a single container, minimizing the use of valuable Pod resources.
10. **Multiple Registries**: Supports Nexus3, Harbor (2.10+), and AWS ECR as Docker and Helm chart registries. The `helm push` plugin is no longer required.
11. **Registry Support**: Also supports a standard Docker registry.
12. **Bilingual Logs**: Console output logs support both Chinese and English, defaulting to English.
13. **Jenkins Integration**: Easily integrates with Jenkins Pipelines using a single entry-point script.
14. **Shell-based**: All code is developed in Shell, offering maximum flexibility and adaptability for users. The learning curve is minimal for developers of any language.
15. **Powerful YAML Tooling**: Features a powerful, originally developed tool for reading and writing YAML files, providing great convenience for custom extensions.
16. **Three-tier Management Model**: Designed with a three-tier management model (Company, Language, Project), providing interfaces for personnel at all levels to manage and control the CI/CD process.
17. **K8s Plugin Mechanism**: Provides a plugin mechanism for Kubernetes resource configuration files, allowing developers to easily customize them.
18. **Management Platform**: Based on this project, the maintenance team has developed the `wydevops` Microservice Management Platform (currently not open-source).

## Running Environment

1.  Can be run in the Git Bash command line on Windows.
2.  Can be run in the Bash command line on Linux.
3.  Can be integrated with Jenkins Pipelines via the `Jenkinsfile` provided in the source code.

## Dependencies

1.  **git**
    *   **Ubuntu (Debian/Ubuntu series)**:
        ```bash
        sudo apt update
        sudo apt install -y git
        git --version
        git config --global user.name "Your Name"
        git config --global user.email "you@example.com"
        ```
    *   **Windows**:
        Download and run the official installer from: https://git-scm.com/download/win
        Follow the installation wizard (default options are fine).
        Verify in PowerShell or cmd: `git --version`
        Configure in PowerShell or Git Bash: `git config --global user.name "Your Name"`, `git config --global user.email "you@example.com"`

2.  **libxml2**
    A library for processing XML files. Required only for Java projects to read `pom.xml`. Non-Java projects do not need it.
    *   **Ubuntu**: `sudo apt install libxml2-utils`
    *   **Windows**: `choco install libxml2`

3.  **docker**
    The tool for building and managing Docker images.
    *   **Ubuntu**: `sudo apt install docker-ce`
    *   **Windows**: Download from [Docker Desktop](https://www.docker.com/get-started).

4.  **helm**
    A tool for Kubernetes microservice deployment. This project automatically installs the corresponding `helm` command (built-in version v3.15.1) from the `/tools` directory based on the system architecture. **No user installation is required.**

5.  **kubectl**
    A command-line tool for managing Kubernetes resources.
    *   **Linux**: The project automatically installs the corresponding `kubectl` command from the `/tools` directory. **No user installation is required.**
    *   **Windows**: Users can install Docker Desktop and enable its built-in Kubernetes cluster (convenient for local debugging), which includes `kubectl`. Alternatively, run `choco install kubectl`.
        After installation, you need to configure the `KUBECONFIG` environment variable to point to your cluster's configuration file.

6.  **Istio in Kubernetes Cluster**
    By default, `wydevops` deploys microservices using the Istio sidecar model. Therefore, Istio must be installed in the target Kubernetes cluster (see [installation guide](https://istio.io/latest/docs/setup/getting-started/)).
    *   **Note**: `wydevops` dynamically fetches the `apiVersion` for all generated Kubernetes resource types from the target cluster to ensure version consistency.

7.  **Local Compilation Dependencies for Target Language**
    The project supports various languages, each with its own compilation dependencies (e.g., JDK for Java). Please install them as needed.
    *   **Note**: If you use the in-Docker compilation method, you do not need to install these local dependencies.

## Shell Source Code Deployment

1.  Create a root directory for `wydevops` and define the `WYDEVOPS_HOME` environment variable pointing to it.
2.  In the `$WYDEVOPS_HOME` directory, clone the project source code:
    `git clone -b master https://github.com/sichuanwuyi/wydevops.git`
    or
    `git clone -b master https://gitee.com/tmt_china/wydevops.git`
3.  Create a `$WYDEVOPS_HOME/client-config.json` file with the following content to enable automatic updates:
    ```json
    {
      "repoUrl": "https://gitee.com/tmt_china/wydevops.git",
      "branch": "master"
    }
    ```
4.  Define the `WYDEVOPS_LOG_LANGUAGE` environment variable (`en` or `zh`, defaults to `en`).
5.  Define the `WYDEVOPS_WORK_MODE` environment variable (`local` or `jenkins`, defaults to `local`).
6.  Install the third-party dependencies mentioned above.
7.  Verify the installation by running: `bash $WYDEVOPS_HOME/wydevops/script/wydevops.sh -h`. No errors indicate a successful installation.

## Integration with Your Project (Source Code Deployment)

1.  Copy the `$WYDEVOPS_HOME/wydevops/script/wydevops-run.sh` file to your target project's root directory.
2.  Modify the `wydevops-run.sh` file in your project to configure the parameters for the `wydevops.sh` execution command:
    *   `-I`: Specify the cache directory for third-party Docker images (defaults to `~/.wydevops/cachedImage`).
    *   `-L`: Specify the project's language type (`java`, `go`, `nextjs`, `vue`).
    *   `-A`: Confirm the architecture for the build (`linux/amd64` or `linux/arm64`, defaults to `linux/amd64`).
    *   `-O`: Confirm the architecture for the offline package (`linux/amd64` or `linux/arm64`, defaults to `linux/amd64`).
    *   For other parameters, run `bash $WYDEVOPS_HOME/wydevops/script/wydevops.sh -h`.
3.  Create a `ci-cd-config.yaml` file in your project's root directory. The following parameters are mandatory under `globalParams`:
    *   `serviceName`: Name of the microservice.
    *   `businessVersion`: Version of the microservice.
    *   `mainPort`: Main port number (multiple ports can be comma-separated).
    *   `gatewayHost`: Gateway domain (defaults to `*`).
    *   `gatewayPath`: Gateway path prefix (defaults to `/${serviceName}`).
    *   `livenessProbeEnable`: Whether to enable K8s liveness probes (defaults to `true`).
    *   `livenessUri`: URI for the liveness probe (required if enabled, defaults to `/health`).
    *   `readinessProbeEnable`: Whether to enable K8s readiness probes (defaults to `true`).
    *   `readinessUri`: URI for the readiness probe (required if enabled, defaults to `/health`).
    *   `targetApiServer`: SSH parameters for the target K8s cluster node server. Format: `{IP}|{Port}|{User}|{Password}`.
    *   `targetNamespace`: Target deployment namespace (defaults to `default`).
    *   `targetDockerRepo`: Image registry information for the K8s cluster. Format: `{type},{name},{address},{user},{password}`.
    *   For a comprehensive list of all parameters, refer to the `_ci-cd-template.yaml` files in the `$WYDEVOPS_HOME/wydevops/script/templates/config` directory.

## Using Docker Deployment

### Building the Docker Image for Java Projects

1.  The `Dockerfile_jdk21` file in the project root is used to build the Docker image for `wydevops`-adapted Java projects.
2.  In the project root, execute: `docker build -t wydevops-runner:1.2.0 -f Dockerfile_jdk21 .`
3.  After the build is complete, modify and run the `docker-build.sh` script to package and deploy your Java project. 
    The script includes volume mounts for the Maven repository, settings.xml, Docker socket, and project source code, as well as environment variables and parameters for the `wydevops` run.
    The content of the docker-build.sh script is as follows:
    
    docker rm -f wydevops-runner && \  # Remove any existing container with the same name
    docker run \
    # Mount the local Maven repository to the container's Maven repository directory
    -v /mnt/d/maven-repository:/root/.m2/repository \
    # Mount the local Maven's settings.xml file to the container's Maven settings.xml file
    -v /mnt/d/apache-maven-3.9.12/conf/settings-docker.xml:/root/.m2/settings.xml \
    # Mount the local docker.sock file to the container's docker.sock file
    -v /var/run/docker.sock:/var/run/docker.sock \
    # Specify the target project's root directory to the container's project root directory
    -v /mnt/d/tmt_project/tmt-ignite3-server:/root/project \
    # Mount the local wydevops directory to the container's wydevops directory; the image will automatically download or update the wydevops source code
    -v /home/wuyi/wydevops:/root/.wydevops/wydevops \
    # Specify the log language for wydevops runtime as Chinese. Valid values: zh, en. Defaults to en.
    -e WYDEVOPS_LOG_LANGUAGE="zh" \
    # Specify the name of the wydevops container as wydevops-runner
    --name wydevops-runner \
    # Specify the wydevops image as wydevops-runner:1.2.0
    wydevops-runner:1.2.0 \
    # Specify the architecture type for this build as linux/arm64
    -A "linux/arm64" \
    # Specify the image architecture type in the generated offline package
    -O "linux/arm64" \
    # Specify that a single Docker image will be generated. If set to "double", two images will be created: a base image and a business image.
    -B "single" \
    # Default deployment mode is K8s. This requires targetApiServer, targetNamespace, and targetDockerRepo to be configured in ci-cd-config.yaml.
    -R "k8s" \
    # Specify the sequence of steps for this process: build, docker, chart, package, deploy.
    -S "build,docker,chart,package,deploy"

5. The `wydevops` team is preparing packaging images for Go, Vue, and Next.js. Stay tuned.

## Deep Customization for Specific Project Types

For Java and Go projects, `wydevops` offers deep customization through `params-mapping-in-*-file.config` files. This mechanism binds `wydevops` parameters to parameters within the project's native configuration files (e.g., `application.yaml` or `pom.xml`), allowing `wydevops` to automatically extract these values at runtime. This enforces development standards within the organization.

*   **Java Project Default Specification**: Defines rules for `application.yaml` location, production profile naming (`application-prod.yaml`), and parameter mappings from `application*.yaml` and `pom.xml`.
*   **Go Project Default Specification**: Defines rules for the production configuration file name (`config-prod.yaml`) and parameter mappings within it (e.g., `app.appName` to `globalParams.serviceName`).

**Note**: Any `wydevops` parameter defined with a binding rule in a `params-mapping-in-*-file.config` file does not need to be defined in `ci-cd-config.yaml`.

## Sample Projects

The `/sample` directory in the source code contains example projects for Java, Go, Next.js, and Vue. Developers interested can refer to these simple examples.

## 💼 Commercial Support & Services

We offer a range of paid services for enterprises and teams with professional needs, designed to help you maximize the value of `wydevops`.

Services include:
1.  **Consulting & Implementation**
2.  **Custom Feature Development**
3.  **Premium Technical Support**

If you or your team are interested in leveraging our expertise to accelerate your DevOps process, please feel free to contact us.

**Contact**: `11372349@qq.com`

## wydevops Microservice Management Platform (V1.0.0)

Based on the offline installation packages for microservices packaged by wydevops, the team has developed a microservice management platform for managing microservice deployment, monitoring, logging, etc.
This platform is not yet open-sourced and will be further improved and optimized within the team. The main core interfaces are shown below:

1.  Login Interface ![](docs/images/登录.png)
2.  Cluster Overview Interface ![](docs/images/集群总览.jpg)
3.  Cluster Node Interface ![](docs/images/集群节点详情1.jpg) ![](docs/images/集群节点详情2.jpg)
4.  Application List Interface ![](docs/images/应用列表.jpg)
5.  Service List Interface ![](docs/images/服务列表.jpg)
6.  User Management Interface ![](docs/images/用户权限管理1.jpg) ![](docs/images/用户权限管理2.jpg)
7.  Offline Package Slice Upload Interface ![](docs/images/离线安装包上传界面.jpg)
8.  Post-Upload Decompression and Verification Interface ![](docs/images/上传后解压验证界面.jpg)
9.  Application Installation Process Interface ![](docs/images/部署详情1.jpg) ![](docs/images/部署详情2.jpg)
10. Dynamic Configuration Parameter Modification Interface ![](docs/images/安装时参数配置界面1.jpg) ![](docs/images/安装时参数配置界面2.jpg)
11. Istio-based Canary Release Interface ![](docs/images/基于istio的灰度发布配置界面.jpg) ![](docs/images/灰度发布结果界面.jpg)
12. Application Log Viewing Interface ![](docs/images/服务运行日志查询.jpg)
13. Container Command Line Interface ![](docs/images/容器命令行界面.jpg)