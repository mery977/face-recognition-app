// Fonctions utilitaires pour l'application

class FaceRecognitionApp {
    constructor() {
        this.video = null;
        this.canvas = null;
        this.stream = null;
        this.isCapturing = false;
        this.detectionInterval = null;
        
        this.init();
    }
    
    init() {
        this.setupEventListeners();
        this.checkCameraSupport();
    }
    
    setupEventListeners() {
        // Écouteurs d'événements globaux
        document.addEventListener('visibilitychange', () => {
            if (document.hidden && this.stream) {
                this.stopCamera();
            }
        });
        
        // Gestion des erreurs globales
        window.addEventListener('error', (e) => {
            console.error('Erreur application:', e.error);
            this.showNotification('Une erreur est survenue', 'error');
        });
    }
    
    checkCameraSupport() {
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            this.showNotification('Votre navigateur ne supporte pas l\'accès à la caméra', 'error');
            return false;
        }
        return true;
    }
    
    async startCamera(videoElement, options = {}) {
        const defaultOptions = {
            video: {
                width: { ideal: 640 },
                height: { ideal: 480 },
                facingMode: 'user'
            }
        };
        
        const constraints = { ...defaultOptions, ...options };
        
        try {
            this.stream = await navigator.mediaDevices.getUserMedia(constraints);
            this.video = videoElement;
            this.video.srcObject = this.stream;
            await this.video.play();
            
            this.showNotification('Caméra activée avec succès', 'success');
            return true;
            
        } catch (error) {
            console.error('Erreur démarrage caméra:', error);
            
            let message = 'Impossible d\'accéder à la caméra';
            if (error.name === 'NotAllowedError') {
                message = 'Accès à la caméra refusé. Veuillez autoriser l\'accès.';
            } else if (error.name === 'NotFoundError') {
                message = 'Aucune caméra trouvée sur cet appareil.';
            }
            
            this.showNotification(message, 'error');
            return false;
        }
    }
    
    stopCamera() {
        if (this.stream) {
            this.stream.getTracks().forEach(track => {
                track.stop();
            });
            this.stream = null;
        }
        
        if (this.video) {
            this.video.srcObject = null;
        }
        
        if (this.detectionInterval) {
            clearInterval(this.detectionInterval);
            this.detectionInterval = null;
        }
    }
    
    captureFrame(videoElement, canvasElement) {
        if (!videoElement || !canvasElement) {
            throw new Error('Éléments video et canvas requis');
        }
        
        const canvas = canvasElement;
        const ctx = canvas.getContext('2d');
        
        canvas.width = videoElement.videoWidth;
        canvas.height = videoElement.videoHeight;
        
        ctx.drawImage(videoElement, 0, 0);
        
        return canvas.toDataURL('image/jpeg', 0.8);
    }
    
    async detectFace(imageData) {
        try {
            const response = await fetch('/api/detect-face', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ image: imageData })
            });
            
            const result = await response.json();
            return result;
            
        } catch (error) {
            console.error('Erreur détection visage:', error);
            return { success: false, message: 'Erreur de détection' };
        }
    }
    
    async authenticate(imageData) {
        try {
            const response = await fetch('/api/login', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ image: imageData })
            });
            
            const result = await response.json();
            return result;
            
        } catch (error) {
            console.error('Erreur authentification:', error);
            return { success: false, message: 'Erreur d\'authentification' };
        }
    }
    
    showNotification(message, type = 'info', duration = 5000) {
        // Créer la notification
        const notification = document.createElement('div');
        notification.className = `alert alert-${this.getBootstrapClass(type)} alert-dismissible fade show position-fixed`;
        notification.style.cssText = `
            top: 20px;
            right: 20px;
            z-index: 9999;
            min-width: 300px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3);
        `;
        
        const icon = this.getIcon(type);
        notification.innerHTML = `
            <i class="${icon} me-2"></i>
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;
        
        document.body.appendChild(notification);
        
        // Auto-suppression
        setTimeout(() => {
            if (notification.parentNode) {
                notification.remove();
            }
        }, duration);
        
        return notification;
    }
    
    getBootstrapClass(type) {
        const classes = {
            'success': 'success',
            'error': 'danger',
            'warning': 'warning',
            'info': 'info'
        };
        return classes[type] || 'info';
    }
    
    getIcon(type) {
        const icons = {
            'success': 'fas fa-check-circle',
            'error': 'fas fa-exclamation-circle',
            'warning': 'fas fa-exclamation-triangle',
            'info': 'fas fa-info-circle'
        };
        return icons[type] || 'fas fa-info-circle';
    }
    
    showLoading(element, show = true) {
        if (!element) return;
        
        const spinner = element.querySelector('.loading-spinner');
        const icon = element.querySelector('i:not(.loading-spinner i)');
        
        if (show) {
            element.disabled = true;
            if (spinner) spinner.style.display = 'inline-block';
            if (icon) icon.style.display = 'none';
        } else {
            element.disabled = false;
            if (spinner) spinner.style.display = 'none';
            if (icon) icon.style.display = 'inline';
        }
    }
    
    validateImageFile(file, maxSize = 16 * 1024 * 1024) {
        if (!file) {
            return { valid: false, message: 'Aucun fichier sélectionné' };
        }
        
        const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];
        if (!allowedTypes.includes(file.type)) {
            return { valid: false, message: 'Format de fichier non supporté' };
        }
        
        if (file.size > maxSize) {
            return { valid: false, message: 'Fichier trop volumineux (max 16MB)' };
        }
        
        return { valid: true };
    }
    
    previewImage(file, previewElement) {
        if (!file || !previewElement) return;
        
        const reader = new FileReader();
        reader.onload = (e) => {
            previewElement.innerHTML = `
                <img src="${e.target.result}" class="img-thumbnail" style="max-width: 200px; max-height: 200px;">
                <p class="text-white-50 small mt-2">Aperçu de votre photo</p>
            `;
        };
        reader.readAsDataURL(file);
    }
    
    // Détection automatique de visage en temps réel
    startFaceDetection(videoElement, callback, interval = 1000) {
        if (this.detectionInterval) {
            clearInterval(this.detectionInterval);
        }
        
        this.detectionInterval = setInterval(() => {
            if (videoElement && videoElement.readyState === 4) {
                try {
                    const canvas = document.createElement('canvas');
                    const imageData = this.captureFrame(videoElement, canvas);
                    
                    // Appeler la fonction de callback avec les données d'image
                    if (callback && typeof callback === 'function') {
                        callback(imageData);
                    }
                } catch (error) {
                    console.error('Erreur détection automatique:', error);
                }
            }
        }, interval);
    }
    
    stopFaceDetection() {
        if (this.detectionInterval) {
            clearInterval(this.detectionInterval);
            this.detectionInterval = null;
        }
    }
    
    // Utilitaires de formatage
    formatDate(dateString) {
        const date = new Date(dateString);
        return date.toLocaleDateString('fr-FR', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }
    
    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }
    
    // Gestion des erreurs réseau
    async makeRequest(url, options = {}) {
        const defaultOptions = {
            headers: {
                'Content-Type': 'application/json',
            }
        };
        
        const mergedOptions = { ...defaultOptions, ...options };
        
        try {
            const response = await fetch(url, mergedOptions);
            
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            return await response.json();
            
        } catch (error) {
            console.error('Erreur requête:', error);
            
            if (error.name === 'TypeError') {
                throw new Error('Erreur de connexion au serveur');
            } else {
                throw error;
            }
        }
    }
}

// Instance globale de l'application
const faceApp = new FaceRecognitionApp();

// Fonctions utilitaires globales
window.showMessage = (message, type = 'info') => {
    faceApp.showNotification(message, type);
};

window.toggleLoading = (show, buttonId) => {
    const button = document.getElementById(buttonId);
    if (button) {
        faceApp.showLoading(button, show);
    }
};

// Export pour utilisation dans d'autres scripts
if (typeof module !== 'undefined' && module.exports) {
    module.exports = FaceRecognitionApp;
}