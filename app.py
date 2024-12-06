from flask import Flask, request, jsonify
import uuid

app = Flask(__name__)

users = {}

@app.route('/', methods=['GET'])
def hello():
    return '<h1>Hello world</h1>'


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)

