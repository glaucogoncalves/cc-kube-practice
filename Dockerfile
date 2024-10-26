FROM php:7.4-apache

# Instalar extensões do MySQL necessárias
RUN docker-php-ext-install mysqli pdo pdo_mysql

# Copiar os arquivos da aplicação PHP para o diretório do Apache
COPY TODO-Application/ /var/www/html/

# Expor a porta do Apache
EXPOSE 80
