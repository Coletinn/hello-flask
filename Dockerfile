FROM python:3.11-slim

WORKDIR /app

COPY . .

COPY requirements.txt .

RUN pip install -r requirements.txt

EXPOSE 5000

CMD ["python", "app.py"]