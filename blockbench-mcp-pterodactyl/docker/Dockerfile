FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    build-essential \
    python3 \
    python3-pip \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN git clone https://github.com/JannisX11/blockbench.git .

RUN npm install

EXPOSE 8080

CMD ["npm", "start"]