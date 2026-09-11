// REQ-ID: REQ-FIN-JNL-001, REQ-FIN-JNL-002
// FEAT-ID: FEAT-FIN-JNL-001
// Module: MOD-FINANCE

using System;
using System.Collections.Generic;
using System.Linq;

namespace Eureka.Modules.Finance.Domain.Entities;

public class JournalEntry
{
    public Guid Id { get; private set; }
    public Guid InvoiceId { get; private set; }  // FK intra-module → Invoice.Id
    public DateTime EntryDate { get; private set; }
    public string Description { get; private set; } = string.Empty;
    public ICollection<JournalLine> Lines { get; private set; } = new List<JournalLine>();

    private JournalEntry() { }

    public static JournalEntry CreateFromInvoice(Guid invoiceId, string description)
        => new() { Id = Guid.NewGuid(), InvoiceId = invoiceId, Description = description, EntryDate = DateTime.UtcNow };

    /// <summary>
    /// REQ-FIN-JNL-002: Double-entry bookkeeping invariant — tổng debit = tổng credit.
    /// </summary>
    public void ValidateBalance()
    {
        var totalDebit = Lines.Sum(l => l.Debit);
        var totalCredit = Lines.Sum(l => l.Credit);
        if (totalDebit != totalCredit)
            throw new InvalidOperationException($"Mất cân bằng kế toán: Debit {totalDebit} ≠ Credit {totalCredit}");
    }
}

public class JournalLine
{
    public Guid Id { get; private set; }
    public Guid JournalEntryId { get; private set; }
    public string AccountCode { get; private set; } = string.Empty;
    public decimal Debit { get; private set; }
    public decimal Credit { get; private set; }
}
