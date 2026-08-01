// main.js - Main application logic

document.addEventListener('DOMContentLoaded', () => {
    initializeEventListeners();
});

function initializeEventListeners() {
    const contactForm = document.getElementById('contact-form');
    if (contactForm) {
        contactForm.addEventListener('submit', handleFormSubmit);
    }

    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const target = link.getAttribute('href');
            scrollToSection(target);
        });
    });
}

async function handleFormSubmit(e) {
    e.preventDefault();

    const name = document.getElementById('name').value;
    const email = document.getElementById('email').value;
    const message = document.getElementById('message').value;

    if (!name || !email || !message) {
        displayMessage('form-status', 'Please fill in all fields.', 'error');
        return;
    }

    if (!isValidEmail(email)) {
        displayMessage('form-status', 'Please enter a valid email address.', 'error');
        return;
    }

    displayMessage('form-status', 'Sending your message...', '');

    try {
        const response = await apiRequest('/api/send-email', {
            method: 'POST',
            body: JSON.stringify({
                name,
                email,
                message,
                timestamp: new Date().toISOString()
            })
        });

        if (response.success) {
            displayMessage('form-status', '✓ Message sent successfully! We will get back to you soon.', 'success');
            clearForm('contact-form');
        } else {
            displayMessage('form-status', '✗ Failed to send message. Please try again.', 'error');
        }
    } catch (error) {
        console.error('Form submission error:', error);
        displayMessage('form-status', '✗ An error occurred. Please try again later.', 'error');
    }
}

function isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
}

function toggleChatbot() {
    const chatbotContainer = document.getElementById('chatbot-container');
    if (chatbotContainer) {
        chatbotContainer.classList.toggle('active');
        const button = document.querySelector('.chat-toggle');
        if (chatbotContainer.classList.contains('active')) {
            button.textContent = 'Close Chat';
        } else {
            button.textContent = 'Open Chat';
        }
    }
}

function initializeChatbot() {
    console.log('Chatbot initialization placeholder');
}
