import {
  Controller, Get, Post, Patch, Delete, Body, Param, Query,
  UseGuards, Request, UsePipes, ValidationPipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { AdminService } from './admin.service';
import { ResetPasswordDto } from './dto/reset-password.dto';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  // ── Audit Log ──────────────────────────────────────────────────────────────
  @Get('audit-log')
  getAuditLog(
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('action') action?: string,
    @Query('skip') skip?: string,
    @Query('limit') limit?: string,
  ) {
    const f = from ? new Date(from) : new Date(Date.now() - 7 * 86400000);
    const t = to ? new Date(to) : new Date();
    const s = skip ? parseInt(skip, 10) : 0;
    const l = limit ? parseInt(limit, 10) : 100;
    return this.adminService.getAuditLog(f, t, action, s, l);
  }

  // ── Password Reset ─────────────────────────────────────────────────────────
  @Post('users/:id/reset-password')
  @UsePipes(new ValidationPipe({ whitelist: true }))
  resetPassword(
    @Param('id') id: string,
    @Body() dto: ResetPasswordDto,
    @Request() req: any,
  ) {
    return this.adminService.resetPassword(id, dto.newPassword, req.user._id);
  }

  // ── Financial Summary (EOD reconciliation) ─────────────────────────────────
  @Get('financial-summary')
  financialSummary(@Query('date') date?: string) {
    const d = date ? new Date(date) : new Date();
    return this.adminService.getFinancialSummary(d);
  }

  // ── Transaction Log ────────────────────────────────────────────────────────
  @Get('transactions')
  transactions(
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('isPaid') isPaid?: string,
  ) {
    const f = from ? new Date(from) : new Date(Date.now() - 30 * 86400000);
    const t = to ? new Date(to) : new Date();
    const paid = isPaid !== undefined ? isPaid === 'true' : undefined;
    return this.adminService.getTransactions(f, t, paid);
  }

  // ── Refund ─────────────────────────────────────────────────────────────────
  @Patch('billing/:id/refund')
  refund(@Param('id') id: string, @Request() req: any) {
    return this.adminService.processRefund(id, req.user);
  }

  // ── Profit Margin ──────────────────────────────────────────────────────────
  @Get('profit-margin')
  profitMargin(@Query('from') from?: string, @Query('to') to?: string) {
    const f = from ? new Date(from) : new Date(Date.now() - 30 * 86400000);
    const t = to ? new Date(to) : new Date();
    return this.adminService.getProfitMargin(f, t);
  }

  // ── Force Close Order ──────────────────────────────────────────────────────
  @Patch('orders/:id/force-close')
  forceClose(@Param('id') id: string, @Request() req: any) {
    return this.adminService.forceCloseOrder(id, req.user._id);
  }

  // ── Hard Delete Order ─────────────────────────────────────────────────────
  // Purge the order document entirely — used to clean up test/demo/orphan
  // orders that were never real transactions. Different from Force Close,
  // which leaves an audited CLOSED order behind. Always logged in the
  // audit feed before removal.
  @Delete('orders/:id')
  deleteOrder(@Param('id') id: string, @Request() req: any) {
    return this.adminService.deleteOrder(id, req.user._id);
  }

  // ── Bulk cleanup of orphan orders ─────────────────────────────────────────
  // Removes orders whose branchId no longer maps to any current branch —
  // these accumulate when a branch is deleted while leftover CREATED orders
  // still reference it, and they're the ones that show under "All Branches"
  // but never under any specific branch filter (nothing to attribute them to).
  @Post('orders/wipe-orphans')
  wipeOrphanOrders(@Request() req: any) {
    return this.adminService.wipeOrphanOrders(req.user._id);
  }

  // ── System Health ──────────────────────────────────────────────────────────
  @Get('system-health')
  systemHealth() {
    return this.adminService.getSystemHealth();
  }

  // ── Wipe demo seed data ───────────────────────────────────────────────────
  // One-shot cleanup for the canned data the `seed.ts` script pushed for
  // first-launch demos. Removes the orders + bills it created (matched
  // by their `seed-*` idempotency keys) so the live dashboard reflects
  // only real transactions. Leaves users, menu items, tables, and
  // ingredients intact — those are useful even outside the demo.
  @Post('wipe-demo-data')
  wipeDemoData(@Request() req: any) {
    return this.adminService.wipeDemoData(req.user._id);
  }
}
