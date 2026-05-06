"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const dotenv = require("dotenv");
dotenv.config();
const URI = process.env.MONGODB_URI;
const DB = process.env.DB_NAME ?? 'rms';
const UserSchema = new mongoose.Schema({
    name: String, email: { type: String, unique: true, lowercase: true },
    password: String, role: String, isActive: { type: Boolean, default: true },
}, { timestamps: true });
const MenuItemSchema = new mongoose.Schema({
    name: String, description: String, category: String,
    basePrice: Number, isAvailable: { type: Boolean, default: true },
    prepTimeMinutes: Number,
    variants: { type: Array, default: [] },
    modifiers: { type: Array, default: [] },
    ingredients: { type: Array, default: [] },
}, { timestamps: true });
const TableSchema = new mongoose.Schema({
    label: { type: String, unique: true }, capacity: Number,
    status: { type: String, default: 'available' },
    activeOrderId: String, qrCode: String,
}, { timestamps: true });
const IngredientSchema = new mongoose.Schema({
    name: { type: String, unique: true }, unit: String,
    currentStock: Number, lowStockThreshold: Number,
    costPerUnit: { type: Number, default: 0 },
    stockLog: { type: Array, default: [] },
}, { timestamps: true });
const OrderItemSchema = new mongoose.Schema({
    itemId: String, name: String, quantity: Number,
    unitPrice: Number, progress: { type: Number, default: 0 }, notes: String,
}, { _id: false });
const OrderSchema = new mongoose.Schema({
    tableId: String, tableLabel: String,
    items: [OrderItemSchema],
    status: { type: String, default: 'created' },
    version: { type: Number, default: 1 },
    processedKeys: { type: [String], default: [] },
    waiterId: String, notes: String,
    subtotal: Number, gstAmount: Number, discountAmount: { type: Number, default: 0 }, total: Number,
    auditLog: { type: Array, default: [] },
}, { timestamps: true });
const BillSchema = new mongoose.Schema({
    orderId: mongoose.Schema.Types.ObjectId,
    tableLabel: String, subtotal: Number,
    discountAmount: { type: Number, default: 0 },
    discountPercent: { type: Number, default: 0 },
    gstAmount: Number, total: Number,
    paymentMethod: String,
    splitPayments: { type: Array, default: [] },
    isPaid: { type: Boolean, default: false },
    paidAt: Date, cashierId: String,
    processedKeys: { type: [String], default: [] },
}, { timestamps: true });
async function seed() {
    await mongoose.connect(URI, { dbName: DB });
    console.log('✅ Connected to MongoDB Atlas →', DB);
    const User = mongoose.model('User', UserSchema);
    const MenuItem = mongoose.model('MenuItem', MenuItemSchema);
    const Table = mongoose.model('Table', TableSchema);
    const Ingredient = mongoose.model('Ingredient', IngredientSchema);
    const Order = mongoose.model('Order', OrderSchema);
    const Bill = mongoose.model('Bill', BillSchema);
    console.log('\n👤 Seeding users...');
    const users = [
        { name: 'Admin User', email: 'admin@dineops.com', password: 'Admin@123', role: 'admin' },
        { name: 'Manager Sam', email: 'manager@dineops.com', password: 'Manager@123', role: 'manager' },
        { name: 'Waiter Alex', email: 'waiter@dineops.com', password: 'Waiter@123', role: 'waiter' },
        { name: 'Chef Marco', email: 'chef@dineops.com', password: 'Chef@123', role: 'chef' },
        { name: 'Cashier Priya', email: 'cashier@dineops.com', password: 'Cashier@123', role: 'cashier' },
    ];
    const userIds = {};
    for (const u of users) {
        let doc = await User.findOne({ email: u.email });
        if (!doc) {
            const hashed = await bcrypt.hash(u.password, 10);
            doc = await User.create({ ...u, password: hashed });
            console.log(`  ✅ Created ${u.role}: ${u.email} / ${u.password}`);
        }
        else {
            console.log(`  ℹ️  Exists  ${u.role}: ${u.email}`);
        }
        userIds[u.role] = doc._id;
    }
    console.log('\n🍽️  Seeding menu...');
    const menuItems = [
        { name: 'Chicken Tikka', category: 'Starters', basePrice: 14.99, prepTimeMinutes: 15, description: 'Grilled chicken marinated in spices', isAvailable: true,
            variants: [{ name: 'Half', price: 8.99 }, { name: 'Full', price: 14.99 }],
            modifiers: [{ name: 'Extra Spicy', extraPrice: 0 }, { name: 'Cheese Topping', extraPrice: 1.5 }] },
        { name: 'Vegan Burger', category: 'Mains', basePrice: 12.50, prepTimeMinutes: 12, description: 'Plant-based patty with fresh veggies', isAvailable: true,
            variants: [], modifiers: [{ name: 'No Onion', extraPrice: 0 }] },
        { name: 'Fish & Chips', category: 'Mains', basePrice: 16.00, prepTimeMinutes: 18, description: 'Crispy battered fish with fries', isAvailable: true,
            variants: [], modifiers: [] },
        { name: 'Margherita Pizza', category: 'Mains', basePrice: 13.00, prepTimeMinutes: 20, description: 'Classic tomato and mozzarella', isAvailable: true,
            variants: [{ name: 'Small', price: 9.00 }, { name: 'Large', price: 13.00 }], modifiers: [] },
        { name: 'Caesar Salad', category: 'Starters', basePrice: 9.50, prepTimeMinutes: 8, description: 'Romaine lettuce with Caesar dressing', isAvailable: true,
            variants: [], modifiers: [{ name: 'Add Chicken', extraPrice: 3.0 }] },
        { name: 'Lamb Chops', category: 'Mains', basePrice: 24.00, prepTimeMinutes: 25, description: 'Grilled lamb with herb sauce', isAvailable: true,
            variants: [], modifiers: [] },
        { name: 'Garlic Bread', category: 'Sides', basePrice: 4.50, prepTimeMinutes: 5, description: 'Toasted bread with garlic butter', isAvailable: true,
            variants: [], modifiers: [] },
        { name: 'Beef Steak', category: 'Mains', basePrice: 32.00, prepTimeMinutes: 22, description: 'Prime cut beef steak', isAvailable: true,
            variants: [{ name: 'Medium Rare', price: 32.00 }, { name: 'Well Done', price: 32.00 }], modifiers: [] },
        { name: 'Chocolate Lava Cake', category: 'Desserts', basePrice: 8.00, prepTimeMinutes: 10, description: 'Warm chocolate cake with molten center', isAvailable: true,
            variants: [], modifiers: [{ name: 'Add Ice Cream', extraPrice: 2.0 }] },
        { name: 'Mango Lassi', category: 'Beverages', basePrice: 5.00, prepTimeMinutes: 3, description: 'Chilled mango yogurt drink', isAvailable: true,
            variants: [], modifiers: [] },
        { name: 'Red Wine (Glass)', category: 'Beverages', basePrice: 11.00, prepTimeMinutes: 1, description: 'House red wine', isAvailable: true,
            variants: [], modifiers: [] },
        { name: 'Mineral Water', category: 'Beverages', basePrice: 2.50, prepTimeMinutes: 1, description: '500ml still water', isAvailable: true,
            variants: [], modifiers: [] },
    ];
    const menuIds = {};
    for (const m of menuItems) {
        let doc = await MenuItem.findOne({ name: m.name });
        if (!doc) {
            doc = await MenuItem.create(m);
            console.log(`  ✅ Created menu item: ${m.name} (${m.category}) — $${m.basePrice}`);
        }
        else {
            console.log(`  ℹ️  Exists: ${m.name}`);
        }
        menuIds[m.name] = doc._id;
    }
    console.log('\n🪑 Seeding tables...');
    const tables = [
        { label: 'Table 1', capacity: 2, status: 'available' },
        { label: 'Table 2', capacity: 2, status: 'available' },
        { label: 'Table 3', capacity: 4, status: 'occupied' },
        { label: 'Table 4', capacity: 4, status: 'available' },
        { label: 'Table 5', capacity: 4, status: 'occupied' },
        { label: 'Table 6', capacity: 4, status: 'reserved' },
        { label: 'Table 7', capacity: 4, status: 'occupied' },
        { label: 'Table 8', capacity: 6, status: 'available' },
        { label: 'Table 9', capacity: 6, status: 'available' },
        { label: 'Table 10', capacity: 6, status: 'cleaning' },
        { label: 'Table 11', capacity: 2, status: 'available' },
        { label: 'Table 12', capacity: 4, status: 'occupied' },
        { label: 'Table 13', capacity: 4, status: 'available' },
        { label: 'Table 14', capacity: 6, status: 'available' },
        { label: 'Table 15', capacity: 8, status: 'reserved' },
    ];
    const tableIds = {};
    for (const t of tables) {
        let doc = await Table.findOne({ label: t.label });
        if (!doc) {
            doc = await Table.create(t);
            console.log(`  ✅ Created ${t.label} (${t.capacity} seats, ${t.status})`);
        }
        else {
            console.log(`  ℹ️  Exists: ${t.label}`);
        }
        tableIds[t.label] = doc._id;
    }
    console.log('\n📦 Seeding inventory...');
    const ingredients = [
        { name: 'Chicken Breast', unit: 'kg', currentStock: 20, lowStockThreshold: 5, costPerUnit: 8,
            stockLog: [{ delta: 20, reason: 'Initial stock', by: 'admin', at: new Date() }] },
        { name: 'Beef Mince', unit: 'kg', currentStock: 15, lowStockThreshold: 4, costPerUnit: 12,
            stockLog: [{ delta: 15, reason: 'Initial stock', by: 'admin', at: new Date() }] },
        { name: 'Flour', unit: 'kg', currentStock: 50, lowStockThreshold: 10, costPerUnit: 1.5,
            stockLog: [{ delta: 50, reason: 'Initial stock', by: 'admin', at: new Date() }] },
        { name: 'Olive Oil', unit: 'litre', currentStock: 10, lowStockThreshold: 2, costPerUnit: 6,
            stockLog: [{ delta: 10, reason: 'Initial stock', by: 'admin', at: new Date() }] },
        { name: 'Tomatoes', unit: 'kg', currentStock: 25, lowStockThreshold: 5, costPerUnit: 2,
            stockLog: [{ delta: 25, reason: 'Initial stock', by: 'admin', at: new Date() }] },
        { name: 'Mozzarella', unit: 'kg', currentStock: 3, lowStockThreshold: 2, costPerUnit: 14,
            stockLog: [{ delta: 3, reason: 'Initial stock', by: 'admin', at: new Date() }] },
        { name: 'Lettuce', unit: 'kg', currentStock: 1.5, lowStockThreshold: 2, costPerUnit: 3,
            stockLog: [{ delta: 1.5, reason: 'Initial stock', by: 'admin', at: new Date() }] },
        { name: 'Lamb Rack', unit: 'kg', currentStock: 10, lowStockThreshold: 3, costPerUnit: 22,
            stockLog: [{ delta: 10, reason: 'Initial stock', by: 'admin', at: new Date() }] },
        { name: 'Potatoes', unit: 'kg', currentStock: 30, lowStockThreshold: 8, costPerUnit: 1,
            stockLog: [{ delta: 30, reason: 'Initial stock', by: 'admin', at: new Date() }] },
        { name: 'Chocolate', unit: 'kg', currentStock: 5, lowStockThreshold: 1, costPerUnit: 18,
            stockLog: [{ delta: 5, reason: 'Initial stock', by: 'admin', at: new Date() }] },
    ];
    for (const ing of ingredients) {
        const doc = await Ingredient.findOne({ name: ing.name });
        if (!doc) {
            await Ingredient.create(ing);
            const low = ing.currentStock <= ing.lowStockThreshold ? ' ⚠️ LOW' : '';
            console.log(`  ✅ Created: ${ing.name} — ${ing.currentStock} ${ing.unit}${low}`);
        }
        else {
            console.log(`  ℹ️  Exists: ${ing.name}`);
        }
    }
    console.log('\n📋 Seeding orders...');
    const waiterId = userIds['waiter'].toString();
    const chickenId = menuIds['Chicken Tikka']?.toString() ?? 'item1';
    const pizzaId = menuIds['Margherita Pizza']?.toString() ?? 'item2';
    const steakId = menuIds['Beef Steak']?.toString() ?? 'item3';
    const saladId = menuIds['Caesar Salad']?.toString() ?? 'item4';
    const wineId = menuIds['Red Wine (Glass)']?.toString() ?? 'item5';
    const burgerID = menuIds['Vegan Burger']?.toString() ?? 'item6';
    const orderDefs = [
        {
            tableId: tableIds['Table 3']?.toString(), tableLabel: 'Table 3',
            status: 'confirmed', waiterId,
            items: [
                { itemId: chickenId, name: 'Chicken Tikka', quantity: 2, unitPrice: 14.99, progress: 0 },
                { itemId: saladId, name: 'Caesar Salad', quantity: 1, unitPrice: 9.50, progress: 0 },
            ],
            notes: 'No onion in salad',
        },
        {
            tableId: tableIds['Table 5']?.toString(), tableLabel: 'Table 5',
            status: 'preparing', waiterId,
            items: [
                { itemId: pizzaId, name: 'Margherita Pizza', quantity: 1, unitPrice: 13.00, progress: 0.5 },
                { itemId: burgerID, name: 'Vegan Burger', quantity: 2, unitPrice: 12.50, progress: 0.3 },
            ],
            notes: '',
        },
        {
            tableId: tableIds['Table 7']?.toString(), tableLabel: 'Table 7',
            status: 'ready', waiterId,
            items: [
                { itemId: steakId, name: 'Beef Steak', quantity: 1, unitPrice: 32.00, progress: 1.0 },
                { itemId: wineId, name: 'Red Wine (Glass)', quantity: 2, unitPrice: 11.00, progress: 1.0 },
            ],
            notes: 'Steak medium rare',
        },
        {
            tableId: tableIds['Table 12']?.toString(), tableLabel: 'Table 12',
            status: 'served', waiterId,
            items: [
                { itemId: chickenId, name: 'Chicken Tikka', quantity: 1, unitPrice: 14.99, progress: 1.0 },
                { itemId: pizzaId, name: 'Margherita Pizza', quantity: 1, unitPrice: 13.00, progress: 1.0 },
            ],
            notes: '',
        },
    ];
    const createdOrderIds = [];
    for (const o of orderDefs) {
        const existing = await Order.findOne({ tableLabel: o.tableLabel, status: o.status });
        if (!existing) {
            const subtotal = o.items.reduce((s, i) => s + i.unitPrice * i.quantity, 0);
            const gstAmount = +(subtotal * 0.18).toFixed(2);
            const total = +(subtotal + gstAmount).toFixed(2);
            const doc = await Order.create({
                ...o,
                subtotal, gstAmount, total,
                processedKeys: [`seed-${o.tableLabel}-${o.status}`],
                auditLog: [{ action: 'CREATED', by: waiterId, at: new Date() }],
            });
            createdOrderIds.push(doc._id);
            console.log(`  ✅ Order: ${o.tableLabel} → status:${o.status} — $${total}`);
        }
        else {
            createdOrderIds.push(existing._id);
            console.log(`  ℹ️  Exists: ${o.tableLabel} (${o.status})`);
        }
    }
    console.log('\n💳 Seeding bills...');
    const servedOrder = await Order.findOne({ tableLabel: 'Table 12', status: 'served' });
    if (servedOrder) {
        const existingBill = await Bill.findOne({ orderId: servedOrder._id });
        if (!existingBill) {
            const cashierId = userIds['cashier'].toString();
            await Bill.create({
                orderId: servedOrder._id,
                tableLabel: 'Table 12',
                subtotal: servedOrder.subtotal,
                discountAmount: 0,
                discountPercent: 0,
                gstAmount: servedOrder.gstAmount,
                total: servedOrder.total,
                paymentMethod: 'card',
                isPaid: true,
                paidAt: new Date(),
                cashierId,
                processedKeys: ['seed-bill-table12'],
            });
            console.log(`  ✅ Paid bill: Table 12 — $${servedOrder.total} (card)`);
        }
        else {
            console.log(`  ℹ️  Bill exists: Table 12`);
        }
    }
    const readyOrder = await Order.findOne({ tableLabel: 'Table 7', status: 'ready' });
    if (readyOrder) {
        const existingBill = await Bill.findOne({ orderId: readyOrder._id });
        if (!existingBill) {
            await Bill.create({
                orderId: readyOrder._id,
                tableLabel: 'Table 7',
                subtotal: readyOrder.subtotal,
                discountAmount: 0,
                discountPercent: 0,
                gstAmount: readyOrder.gstAmount,
                total: readyOrder.total,
                isPaid: false,
                processedKeys: ['seed-bill-table7'],
            });
            console.log(`  ✅ Pending bill: Table 7 — $${readyOrder.total} (awaiting payment)`);
        }
        else {
            console.log(`  ℹ️  Bill exists: Table 7`);
        }
    }
    await mongoose.disconnect();
    console.log('\n' + '═'.repeat(55));
    console.log('🎉  SEED COMPLETE — DINE OPS');
    console.log('═'.repeat(55));
    console.log('\n📱 Login credentials:\n');
    console.log('  Role      Email                    Password');
    console.log('  ────────  ───────────────────────  ────────────');
    console.log('  admin     admin@dineops.com         Admin@123');
    console.log('  manager   manager@dineops.com       Manager@123');
    console.log('  waiter    waiter@dineops.com        Waiter@123');
    console.log('  chef      chef@dineops.com          Chef@123');
    console.log('  cashier   cashier@dineops.com       Cashier@123');
    console.log('\n🗄️  Collections seeded:');
    console.log('  users · menu_items · tables · ingredients · orders · bills');
    console.log('═'.repeat(55) + '\n');
}
seed().catch(e => { console.error('❌ Seed failed:', e.message); process.exit(1); });
//# sourceMappingURL=seed.js.map