# Este Dockerfile funciona: construye y la app arranca.
# Pero no es un Dockerfile que quieras en producción.
# Revísalo y arréglalo. Explica cada cambio en ENTREGA.md.

FROM python:latest

ENV DB_HOST=localhost
ENV DB_NAME=inventario
ENV DB_USER=inventario
ENV DB_PASSWORD=inventario123

RUN apt-get update && apt-get install -y \
    curl \
    vim \
    net-tools \
    build-essential \
    postgresql-client

WORKDIR /app

COPY . /app

RUN pip install -r requirements.txt

EXPOSE 8080

CMD python app.py
