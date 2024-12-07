# Use the official Python image
FROM python:3.10-slim

# Set the working directory
WORKDIR /app

# Copy the application code
COPY . .

# Install dependencies
RUN pip install -r ../requirements.txt

# Expose the Flask app's port
EXPOSE 5000

# Start the Flask app
CMD ["python", "app.py"]
