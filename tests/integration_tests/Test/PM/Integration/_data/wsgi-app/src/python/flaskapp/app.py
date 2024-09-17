from flask import Flask

app = Flask(__name__)

@app.route("/")
def index():
    return "This is a sample WSGI application using Flask!"