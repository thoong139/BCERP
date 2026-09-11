// pos-04: Migration — shrink column length from nvarchar(max) to nvarchar(50)
// Expected: CHECK 3 signal "Migration data loss" (high, exhaustive only)
// Pattern triggered: grep -rEn finds the Up() single-line call with length argument
// CRITICAL: must be on ONE line for grep -E to match (no multiline mode)
using Microsoft.EntityFrameworkCore.Migrations;
using System;

namespace MyApp.Infrastructure.Migrations
{
    public partial class _20240101_AlterOrderColumns : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(name: "Description", table: "Orders", type: "nvarchar(50)", maxLength: 50, nullable: false, oldClrType: typeof(string), oldType: "nvarchar(max)");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Multi-line format: each arg on its own line so grep single-line pattern won't match
            migrationBuilder.AlterColumn<string>(
                name: "Description",
                table: "Orders",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(50)",
                oldMaxLength: 50);
        }
    }
}
