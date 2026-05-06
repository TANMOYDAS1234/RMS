"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MenuItemSchema = exports.MenuItem = void 0;
const mongoose_1 = require("@nestjs/mongoose");
let Variant = class Variant {
};
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], Variant.prototype, "name", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", Number)
], Variant.prototype, "price", void 0);
Variant = __decorate([
    (0, mongoose_1.Schema)({ _id: false })
], Variant);
let Modifier = class Modifier {
};
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], Modifier.prototype, "name", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 0 }),
    __metadata("design:type", Number)
], Modifier.prototype, "extraPrice", void 0);
Modifier = __decorate([
    (0, mongoose_1.Schema)({ _id: false })
], Modifier);
let MenuItem = class MenuItem {
};
exports.MenuItem = MenuItem;
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], MenuItem.prototype, "name", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", String)
], MenuItem.prototype, "description", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], MenuItem.prototype, "category", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true, min: 0 }),
    __metadata("design:type", Number)
], MenuItem.prototype, "basePrice", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: [Variant], default: [] }),
    __metadata("design:type", Array)
], MenuItem.prototype, "variants", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: [Modifier], default: [] }),
    __metadata("design:type", Array)
], MenuItem.prototype, "modifiers", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: true }),
    __metadata("design:type", Boolean)
], MenuItem.prototype, "isAvailable", void 0);
__decorate([
    (0, mongoose_1.Prop)(),
    __metadata("design:type", String)
], MenuItem.prototype, "imageUrl", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 0 }),
    __metadata("design:type", Number)
], MenuItem.prototype, "prepTimeMinutes", void 0);
__decorate([
    (0, mongoose_1.Prop)({ type: [{ ingredientId: String, quantity: Number, unit: String }], default: [] }),
    __metadata("design:type", Array)
], MenuItem.prototype, "ingredients", void 0);
exports.MenuItem = MenuItem = __decorate([
    (0, mongoose_1.Schema)({ timestamps: true })
], MenuItem);
exports.MenuItemSchema = mongoose_1.SchemaFactory.createForClass(MenuItem);
exports.MenuItemSchema.index({ category: 1, isAvailable: 1 });
//# sourceMappingURL=menu.schema.js.map