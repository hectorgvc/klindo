// carrito.js - Lógica del carrito de compras

class Carrito {
  constructor() {
    this.items = [];
    this.delivery = 0;
    this.loadFromStorage();
  }

  loadFromStorage() {
    const saved = sessionStorage.getItem('cart');
    if (saved) {
      try {
        const data = JSON.parse(saved);
        this.items = data.items || [];
        this.delivery = data.delivery || 0;
      } catch (e) {
        this.items = [];
        this.delivery = 0;
      }
    }
  }

  saveToStorage() {
    sessionStorage.setItem('cart', JSON.stringify({
      items: this.items,
      delivery: this.delivery
    }));
  }

  addItem(product, tenant) {
    const existingItem = this.items.find(item => item.id === product.id);

    if (existingItem) {
      existingItem.cantidad++;
    } else {
      this.items.push({
        id: product.id,
        nombre: product.nombre,
        precio: product.precio,
        imagen_url: product.imagen_url,
        cantidad: 1,
        tenant_id: tenant.id,
        esOferta: product.esOferta || false
      });
    }

    this.saveToStorage();
  }

  removeItem(productId) {
    this.items = this.items.filter(item => item.id !== productId);
    this.saveToStorage();
  }

  updateQuantity(productId, delta) {
    const item = this.items.find(item => item.id === productId);
    if (item) {
      item.cantidad += delta;
      if (item.cantidad <= 0) {
        this.removeItem(productId);
      } else {
        this.saveToStorage();
      }
    }
  }

  setDelivery(amount) {
    this.delivery = amount;
    this.saveToStorage();
  }

  getCart() {
    const subtotal = this.items.reduce((sum, item) => sum + (item.precio * item.cantidad), 0);
    return {
      items: this.items,
      subtotal,
      delivery: this.delivery,
      total: subtotal + this.delivery
    };
  }

  clear() {
    this.items = [];
    this.delivery = 0;
    sessionStorage.removeItem('cart');
  }

  getItemCount() {
    return this.items.reduce((sum, item) => sum + item.cantidad, 0);
  }
}

// Crear instancia global
window.carrito = new Carrito();
