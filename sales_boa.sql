/* 1. TEST VARIABLES */
DECLARE @DocNum NVARCHAR(20) = '3000095'

SELECT 
    ISNULL(T_Branch.BPLName, 'Head Office') AS [Branch],
    
    -- [Count]
    ROW_NUMBER() OVER(ORDER BY Result.LineOrder) AS [Count],

    DATENAME(month, T0.DocDate) AS [Month],
    T0.DocDate AS [Date],
    T0.DocNum AS [SI/DR/OR/CR],
    'Daily Sales' AS [Product Description],
    Result.Particulars,
    Result.CustomerName AS [Name of Customer],
    Result.Address,
    Result.TIN,
    Result.Amount AS [Gross Sales],
    0 AS [Discounts],
    Result.Amount AS [Sales Net of Disc],
    0 AS [EWT],
    0 AS [Vat],
    Result.Amount AS [Net Amount]

FROM OINV T0
LEFT JOIN OBPL T_Branch ON T0.BPLId = T_Branch.BPLId

-- [FIXED JOIN] Link Invoice -> Business Partner -> Customer Group
INNER JOIN OCRD T_BP ON T0.CardCode = T_BP.CardCode
LEFT JOIN OCRG T_Group ON T_BP.GroupCode = T_Group.GroupCode

/* CROSS APPLY: The Magic Logic */
CROSS APPLY (
    
    -- === PART 1: JOURNAL ENTRY SPLITS (Grab, Panda, Maya) ===
    SELECT 
        1 AS LineOrder,
        SPLIT_BP.CardName AS CustomerName,
        ISNULL(T_JE_Line.LineMemo, T0.Comments) AS Particulars,
        LTRIM(RTRIM(ISNULL(SPLIT_ADDR.Street, '') + ' ' + ISNULL(SPLIT_ADDR.City, ''))) AS Address,
        ISNULL(SPLIT_BP.LicTradNum, '') AS TIN,
        T_JE_Line.Debit AS Amount
    FROM ITR1 I_Inv
    INNER JOIN ITR1 I_JE ON I_Inv.ReconNum = I_JE.ReconNum AND I_JE.SrcObjTyp = 30 
    INNER JOIN JDT1 T_JE_Line ON I_JE.SrcObjAbs = T_JE_Line.TransId
    INNER JOIN OCRD SPLIT_BP ON T_JE_Line.ShortName = SPLIT_BP.CardCode 
    LEFT JOIN CRD1 SPLIT_ADDR ON SPLIT_BP.CardCode = SPLIT_ADDR.CardCode AND SPLIT_BP.BillToDef = SPLIT_ADDR.Address AND SPLIT_ADDR.AdresType = 'B'
    WHERE I_Inv.SrcObjAbs = T0.DocEntry AND I_Inv.SrcObjTyp = 13
      AND T_JE_Line.Debit > 0 
      AND T_JE_Line.ShortName <> T0.CardCode 

    UNION ALL

    -- === PART 2: INCOMING PAYMENTS (Walk-In Cash) ===
    SELECT 
        2 AS LineOrder,
        T0.CardName + ' (POS Walk-In)' AS CustomerName, 
        ISNULL(T_Pay.Comments, T0.Comments) AS Particulars,
        ISNULL(CAST(T0.Address AS NVARCHAR(MAX)), '') AS Address,
        T0.LicTradNum AS TIN,
        I_PaySide.ReconSum AS Amount
    FROM ITR1 I_Inv
    INNER JOIN ITR1 I_PaySide ON I_Inv.ReconNum = I_PaySide.ReconNum AND I_PaySide.SrcObjTyp = 24 
    INNER JOIN ORCT T_Pay ON I_PaySide.SrcObjAbs = T_Pay.DocEntry 
    WHERE I_Inv.SrcObjAbs = T0.DocEntry AND I_Inv.SrcObjTyp = 13
      AND I_Inv.IsCredit = 'D'

) AS Result

WHERE 
    T0.DocNum = @DocNum
    -- [FILTER] Only run this for the specific POS Group
    AND T_Group.GroupName = 'Cust-POS Walk-in'