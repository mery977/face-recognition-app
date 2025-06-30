import face_recognition
import cv2
import numpy as np
from flask import Flask, request, jsonify, render_template, redirect, url_for
import os
import json
from datetime import datetime
import pymongo
from bson import ObjectId
import base64
from werkzeug.utils import secure_filename
import logging

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your-secret-key-here'
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Configuration MongoDB
MONGO_URI = "mongodb://mongo:27017/face_recognition_db"
client = pymongo.MongoClient(MONGO_URI)
db = client.face_recognition_db
users_collection = db.users
login_logs_collection = db.login_logs

# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Créer le dossier uploads s'il n'existe pas
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def encode_face_from_file(file_path):
    """Encode un visage à partir d'un fichier image"""
    try:
        image = face_recognition.load_image_file(file_path)
        face_encodings = face_recognition.face_encodings(image)
        
        if len(face_encodings) > 0:
            return face_encodings[0].tolist()  # Convertir en liste pour MongoDB
        else:
            return None
    except Exception as e:
        logger.error(f"Erreur lors de l'encodage du visage: {e}")
        return None

def encode_face_from_array(image_array):
    """Encode un visage à partir d'un array numpy"""
    try:
        face_encodings = face_recognition.face_encodings(image_array)
        
        if len(face_encodings) > 0:
            return face_encodings[0].tolist()
        else:
            return None
    except Exception as e:
        logger.error(f"Erreur lors de l'encodage du visage: {e}")
        return None

def compare_faces(known_encoding, unknown_encoding, tolerance=0.6):
    """Compare deux encodages de visages"""
    try:
        if known_encoding is None or unknown_encoding is None:
            return False
        
        # Convertir en numpy arrays
        known_encoding_np = np.array(known_encoding)
        unknown_encoding_np = np.array(unknown_encoding)
        
        results = face_recognition.compare_faces([known_encoding_np], unknown_encoding_np, tolerance=tolerance)
        return results[0] if results else False
    except Exception as e:
        logger.error(f"Erreur lors de la comparaison: {e}")
        return False

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/register')
def register_page():
    return render_template('register.html')

@app.route('/login')
def login_page():
    return render_template('login.html')

@app.route('/api/register', methods=['POST'])
def register_user():
    try:
        # Récupérer les données du formulaire
        username = request.form.get('username')
        email = request.form.get('email')
        
        if not username or not email:
            return jsonify({'success': False, 'message': 'Nom d\'utilisateur et email requis'})
        
        # Vérifier si l'utilisateur existe déjà
        existing_user = users_collection.find_one({'$or': [{'username': username}, {'email': email}]})
        if existing_user:
            return jsonify({'success': False, 'message': 'Utilisateur déjà existant'})
        
        # Traiter l'image uploadée
        if 'photo' not in request.files:
            return jsonify({'success': False, 'message': 'Aucune photo fournie'})
        
        file = request.files['photo']
        if file.filename == '':
            return jsonify({'success': False, 'message': 'Aucun fichier sélectionné'})
        
        if file and allowed_file(file.filename):
            filename = secure_filename(f"{username}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg")
            file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(file_path)
            
            # Encoder le visage
            face_encoding = encode_face_from_file(file_path)
            
            if face_encoding is None:
                os.remove(file_path)  # Supprimer le fichier si pas de visage détecté
                return jsonify({'success': False, 'message': 'Aucun visage détecté dans l\'image'})
            
            # Sauvegarder dans MongoDB
            user_data = {
                'username': username,
                'email': email,
                'face_encoding': face_encoding,
                'photo_path': file_path,
                'created_at': datetime.now(),
                'is_active': True
            }
            
            result = users_collection.insert_one(user_data)
            
            if result.inserted_id:
                return jsonify({'success': True, 'message': 'Utilisateur enregistré avec succès'})
            else:
                return jsonify({'success': False, 'message': 'Erreur lors de l\'enregistrement'})
        
        return jsonify({'success': False, 'message': 'Format de fichier non supporté'})
        
    except Exception as e:
        logger.error(f"Erreur lors de l'enregistrement: {e}")
        return jsonify({'success': False, 'message': 'Erreur serveur'})

@app.route('/api/login', methods=['POST'])
def login_user():
    try:
        # Récupérer l'image de la caméra (base64)
        image_data = request.json.get('image')
        
        if not image_data:
            return jsonify({'success': False, 'message': 'Aucune image fournie'})
        
        # Décoder l'image base64
        try:
            # Supprimer le préfixe data:image/jpeg;base64,
            if image_data.startswith('data:image'):
                image_data = image_data.split(',')[1]
            
            image_bytes = base64.b64decode(image_data)
            
            # Convertir en array numpy
            nparr = np.frombuffer(image_bytes, np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            
        except Exception as e:
            logger.error(f"Erreur décodage image: {e}")
            return jsonify({'success': False, 'message': 'Format d\'image invalide'})
        
        # Encoder le visage de l'image reçue
        unknown_encoding = encode_face_from_array(image_rgb)
        
        if unknown_encoding is None:
            return jsonify({'success': False, 'message': 'Aucun visage détecté'})
        
        # Comparer avec tous les utilisateurs enregistrés
        users = users_collection.find({'is_active': True})
        
        for user in users:
            known_encoding = user.get('face_encoding')
            
            if compare_faces(known_encoding, unknown_encoding, tolerance=0.6):
                # Connexion réussie - Logger l'événement
                login_log = {
                    'user_id': user['_id'],
                    'username': user['username'],
                    'login_time': datetime.now(),
                    'success': True,
                    'ip_address': request.remote_addr
                }
                login_logs_collection.insert_one(login_log)
                
                return jsonify({
                    'success': True, 
                    'message': f'Connexion réussie. Bienvenue {user["username"]}!',
                    'user': {
                        'username': user['username'],
                        'email': user['email']
                    }
                })
        
        # Aucune correspondance trouvée
        login_log = {
            'username': 'unknown',
            'login_time': datetime.now(),
            'success': False,
            'ip_address': request.remote_addr
        }
        login_logs_collection.insert_one(login_log)
        
        return jsonify({'success': False, 'message': 'Aucune correspondance trouvée'})
        
    except Exception as e:
        logger.error(f"Erreur lors de la connexion: {e}")
        return jsonify({'success': False, 'message': 'Erreur serveur'})

@app.route('/api/users', methods=['GET'])
def get_users():
    try:
        users = list(users_collection.find({'is_active': True}, {'face_encoding': 0}))
        # Convertir ObjectId en string pour JSON
        for user in users:
            user['_id'] = str(user['_id'])
            user['created_at'] = user['created_at'].isoformat()
        
        return jsonify({'success': True, 'users': users})
    except Exception as e:
        logger.error(f"Erreur récupération utilisateurs: {e}")
        return jsonify({'success': False, 'message': 'Erreur serveur'})

@app.route('/api/logs', methods=['GET'])
def get_login_logs():
    try:
        logs = list(login_logs_collection.find().sort('login_time', -1).limit(50))
        # Convertir ObjectId en string pour JSON
        for log in logs:
            log['_id'] = str(log['_id'])
            if 'user_id' in log:
                log['user_id'] = str(log['user_id'])
            log['login_time'] = log['login_time'].isoformat()
        
        return jsonify({'success': True, 'logs': logs})
    except Exception as e:
        logger.error(f"Erreur récupération logs: {e}")
        return jsonify({'success': False, 'message': 'Erreur serveur'})

@app.route('/dashboard')
def dashboard():
    return render_template('dashboard.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80, debug=True)