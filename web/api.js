const API_BASE_URL = 'http://localhost:3000/api';
const QUEUE_KEY = 'ecovision_analytics_queue';

class ApiClient {
    constructor() {
        this.queue = JSON.parse(localStorage.getItem(QUEUE_KEY)) || [];
        
        // Listen for online events to flush the queue
        window.addEventListener('online', () => this.syncQueue());
        
        // Try syncing on initialization just in case
        if (navigator.onLine) {
            this.syncQueue();
        }
    }

    async logAnalytics(category, city = "Unknown") {
        const event = {
            category,
            city,
            timestamp: new Date().toISOString()
        };

        if (navigator.onLine) {
            try {
                await this.sendEvent(event);
            } catch (err) {
                console.warn("Analytics failed, queuing event.", err);
                this.enqueue(event);
            }
        } else {
            console.log("Offline, queuing analytics event.");
            this.enqueue(event);
        }
    }

    enqueue(event) {
        this.queue.push(event);
        localStorage.setItem(QUEUE_KEY, JSON.stringify(this.queue));
    }

    async sendEvent(event) {
        const response = await fetch(`${API_BASE_URL}/analytics`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(event)
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return await response.json();
    }

    async syncQueue() {
        if (this.queue.length === 0) return;

        console.log(`Attempting to sync ${this.queue.length} queued events...`);
        const newQueue = [];

        for (const event of this.queue) {
            try {
                await this.sendEvent(event);
            } catch (err) {
                console.error("Failed to sync event:", err);
                newQueue.push(event); // keep in queue if it fails again
            }
        }

        this.queue = newQueue;
        localStorage.setItem(QUEUE_KEY, JSON.stringify(this.queue));
        
        if (this.queue.length === 0) {
            console.log("All queued events synchronized successfully.");
        }
    }
}

// Expose globally for script.js
window.api = new ApiClient();
