"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const mongoose_1 = require("@nestjs/mongoose");
const throttler_1 = require("@nestjs/throttler");
const core_1 = require("@nestjs/core");
const auth_module_1 = require("./modules/auth/auth.module");
const orders_module_1 = require("./modules/orders/orders.module");
const users_module_1 = require("./modules/users/users.module");
const menu_module_1 = require("./modules/menu/menu.module");
const tables_module_1 = require("./modules/tables/tables.module");
const billing_module_1 = require("./modules/billing/billing.module");
const inventory_module_1 = require("./modules/inventory/inventory.module");
const global_exception_filter_1 = require("./common/filters/global-exception.filter");
const idempotency_interceptor_1 = require("./common/interceptors/idempotency.interceptor");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            config_1.ConfigModule.forRoot({ isGlobal: true }),
            mongoose_1.MongooseModule.forRootAsync({
                inject: [config_1.ConfigService],
                useFactory: (cfg) => ({
                    uri: cfg.get('MONGODB_URI'),
                    dbName: cfg.get('DB_NAME', 'rms'),
                }),
            }),
            throttler_1.ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }]),
            auth_module_1.AuthModule,
            orders_module_1.OrdersModule,
            users_module_1.UsersModule,
            menu_module_1.MenuModule,
            tables_module_1.TablesModule,
            billing_module_1.BillingModule,
            inventory_module_1.InventoryModule,
        ],
        providers: [
            { provide: core_1.APP_FILTER, useClass: global_exception_filter_1.GlobalExceptionFilter },
            { provide: core_1.APP_INTERCEPTOR, useClass: idempotency_interceptor_1.IdempotencyInterceptor },
        ],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map