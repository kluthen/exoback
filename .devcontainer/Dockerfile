FROM php:8.4

# Install sudo and create a non-root user for .devcontainer usage
ARG USERNAME=vscode
ARG UID=1001
ARG GID=1001

# créer groupe et utilisateur, installer sudo et autoriser sudo sans mot de passe
RUN groupadd -g ${GID} ${USERNAME} \
    && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME} \
    && apt-get update -y \
    && apt-get install -y sudo \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}


# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    git \
    zip \
    unzip \
    libzip-dev \
    libpng-dev \
    curl \
    libpq-dev \
    postgresql-client \
    locales \ 
    libicu-dev \
    wget \
    golang-go \
    procps \
    && docker-php-ext-install gd pdo pdo_pgsql zip bcmath intl pcntl \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set the locale
RUN sed -i '/fr_FR.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG fr_FR.UTF-8  
ENV LANGUAGE fr_FR:fr  
ENV LC_ALL fr_FR.UTF-8   

# basculer vers l'utilisateur non-root pour la CMD
USER ${USERNAME}
WORKDIR /workspace

# Keep container running until we create the Symfony project
CMD ["sleep", "infinity"]