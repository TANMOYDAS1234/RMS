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
exports.IngredientSchema = exports.Ingredient = void 0;
const mongoose_1 = require("@nestjs/mongoose");
let Ingredient = class Ingredient {
};
exports.Ingredient = Ingredient;
__decorate([
    (0, mongoose_1.Prop)({ required: true, unique: true }),
    __metadata("design:type", String)
], Ingredient.prototype, "name", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true }),
    __metadata("design:type", String)
], Ingredient.prototype, "unit", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true, min: 0 }),
    __metadata("design:type", Number)
], Ingredient.prototype, "currentStock", void 0);
__decorate([
    (0, mongoose_1.Prop)({ required: true, min: 0 }),
    __metadata("design:type", Number)
], Ingredient.prototype, "lowStockThreshold", void 0);
__decorate([
    (0, mongoose_1.Prop)({ default: 0 }),
    __metadata("design:type", Number)
], Ingredient.prototype, "costPerUnit", void 0);
__decorate([
    (0, mongoose_1.Prop)({
        type: [{ delta: Number, reason: String, by: String, at: Date }],
        default: [],
    }),
    __metadata("design:type", Array)
], Ingredient.prototype, "stockLog", void 0);
exports.Ingredient = Ingredient = __decorate([
    (0, mongoose_1.Schema)({ timestamps: true })
], Ingredient);
exports.IngredientSchema = mongoose_1.SchemaFactory.createForClass(Ingredient);
exports.IngredientSchema.index({ currentStock: 1 });
//# sourceMappingURL=ingredient.schema.js.map