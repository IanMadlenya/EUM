Attribute VB_Name = "FINAN_FI_BOND_BOOTSTRAP_LIBR"
Option Explicit

Public PUB_BOND_PRICES_VECTOR As Variant
Public PUB_BOND_TENOR_VECTOR As Variant
Public PUB_BOND_MATURITY_VECTOR As Variant
Public PUB_BOND_PAYMENTS_MATRIX As Variant

'Enter Input data below for Time points, bond market prices and bond payment schedules

Function BOOTSTRAP_YIELD_CURVE_FUNC(ByRef BOND_PRICES_RNG As Variant, _
ByRef BOND_PAYMENTS_RNG As Variant, _
ByRef BOND_TENOR_RNG As Variant, _
Optional ByVal GUESS_RNG As Variant = 0.01, _
Optional ByVal nLOOPS As Long = 1000, _
Optional ByVal epsilon As Double = 0.001)

Dim i As Long
Dim j As Long

Dim NROWS As Long
Dim NCOLUMNS As Long

Dim TEMP1_VECTOR As Variant 'YieldCurve
Dim TEMP2_VECTOR As Variant 'ForwardCurve

Dim TEMP_MATRIX As Variant
Dim TENOR_VECTOR As Variant

Dim GUESS_VECTOR As Variant
Dim PARAM_VECTOR As Variant

Dim BOND_PRICES_VECTOR As Variant
Dim BOND_TENOR_VECTOR As Variant
Dim BOND_PAYMENTS_MATRIX As Variant

On Error GoTo ERROR_LABEL

BOND_PRICES_VECTOR = BOND_PRICES_RNG
If UBound(BOND_PRICES_VECTOR, 1) = 1 Then
  BOND_PRICES_VECTOR = MATRIX_TRANSPOSE_FUNC(BOND_PRICES_VECTOR)
End If
NROWS = UBound(BOND_PRICES_VECTOR, 1)

BOND_TENOR_VECTOR = BOND_TENOR_RNG
If UBound(BOND_TENOR_VECTOR, 1) = 1 Then
  BOND_TENOR_VECTOR = MATRIX_TRANSPOSE_FUNC(BOND_TENOR_VECTOR)
End If
NCOLUMNS = UBound(BOND_TENOR_VECTOR, 1)

BOND_PAYMENTS_MATRIX = BOND_PAYMENTS_RNG
If UBound(BOND_PAYMENTS_MATRIX, 1) <> NROWS Then: GoTo ERROR_LABEL
If UBound(BOND_PAYMENTS_MATRIX, 2) <> NCOLUMNS Then: GoTo ERROR_LABEL

If IsArray(GUESS_RNG) = True Then
  GUESS_VECTOR = GUESS_RNG
  If UBound(GUESS_VECTOR, 1) = 1 Then
      GUESS_VECTOR = MATRIX_TRANSPOSE_FUNC(GUESS_VECTOR)
  End If
Else
  ReDim GUESS_VECTOR(1 To NROWS, 1 To 1) 'guessForwardRateVec
  For i = 1 To NROWS
    GUESS_VECTOR(i, 1) = GUESS_RNG
  Next i
End If
If UBound(GUESS_VECTOR, 1) <> NROWS Then: GoTo ERROR_LABEL


ReDim TENOR_VECTOR(1 To NROWS, 1 To 1) 'BondMaturityTimesVec

For i = 1 To NROWS
  For j = 1 To NCOLUMNS
    If BOND_PAYMENTS_MATRIX(i, j) > 0 Then
      TENOR_VECTOR(i, 1) = BOND_TENOR_VECTOR(j, 1)
    End If
  Next j
Next i

PUB_BOND_PRICES_VECTOR = BOND_PRICES_VECTOR
PUB_BOND_TENOR_VECTOR = TENOR_VECTOR

PUB_BOND_MATURITY_VECTOR = BOND_TENOR_VECTOR
PUB_BOND_PAYMENTS_MATRIX = BOND_PAYMENTS_MATRIX

PARAM_VECTOR = NELDER_MEAD_OPTIMIZATION3_FUNC("GET_YIELD_OBJ_FUNC", _
               GUESS_VECTOR, nLOOPS, epsilon)

TEMP2_VECTOR = GET_FORWARD_CURVE_FUNC(TENOR_VECTOR, PARAM_VECTOR, BOND_TENOR_VECTOR)
TEMP1_VECTOR = GET_YIELD_CURVE_FUNC(BOND_TENOR_VECTOR, TEMP2_VECTOR)
If UBound(TEMP2_VECTOR, 1) <> UBound(TEMP1_VECTOR, 1) Then: GoTo ERROR_LABEL
j = NCOLUMNS - UBound(TEMP2_VECTOR, 1)
If j < 0 Then: GoTo ERROR_LABEL

NCOLUMNS = UBound(TEMP1_VECTOR, 1)
ReDim TEMP_MATRIX(0 To NCOLUMNS, 1 To 3)

TEMP_MATRIX(0, 1) = "Tn"
TEMP_MATRIX(0, 2) = "R(0,t)"
TEMP_MATRIX(0, 3) = "F(0,t,t+dt)"

For i = 1 To NCOLUMNS
  TEMP_MATRIX(i, 1) = BOND_TENOR_VECTOR(i + j, 1)
  TEMP_MATRIX(i, 2) = TEMP1_VECTOR(i, 1)
  TEMP_MATRIX(i, 3) = TEMP2_VECTOR(i, 1)
Next i

BOOTSTRAP_YIELD_CURVE_FUNC = TEMP_MATRIX
  
Exit Function
ERROR_LABEL:
BOOTSTRAP_YIELD_CURVE_FUNC = Err.number
End Function

Private Function GET_BOND_PRICES_FUNC(ByRef MATURITY_VECTOR As Variant, _
ByRef FORWARD_CURVE_VECTOR As Variant, _
ByRef BOND_PAYMENTS_MATRIX As Variant)

Dim i As Long
Dim j As Long
Dim k As Long
Dim l As Long

Dim TEMP1_SUM As Double 'pvsum
Dim TEMP1_VECTOR As Variant 'BondPVsSum
Dim TEMP2_VECTOR As Variant 'DiscountCurve
Dim TEMP_MATRIX As Variant 'DiscBondPaymentsMatrix

On Error GoTo ERROR_LABEL

k = UBound(BOND_PAYMENTS_MATRIX, 1)
l = UBound(BOND_PAYMENTS_MATRIX, 2)

ReDim TEMP_MATRIX(1 To k, 1 To l)
ReDim TEMP2_VECTOR(1 To l, 1 To 1)

TEMP2_VECTOR(1, 1) = 1
For i = 1 To l - 1
    TEMP2_VECTOR(i + 1, 1) = TEMP2_VECTOR(i, 1) / (1 + (MATURITY_VECTOR(i + 1, 1) - _
                       MATURITY_VECTOR(i, 1)) * FORWARD_CURVE_VECTOR(i, 1))
Next i

ReDim TEMP1_VECTOR(1 To k, 1 To 1)
For i = 1 To k
    TEMP1_SUM = 0
    For j = 1 To l
        TEMP_MATRIX(i, j) = BOND_PAYMENTS_MATRIX(i, j) * TEMP2_VECTOR(j, 1)
        TEMP1_SUM = TEMP1_SUM + TEMP_MATRIX(i, j)
    Next j
    TEMP1_VECTOR(i, 1) = TEMP1_SUM
Next i
GET_BOND_PRICES_FUNC = TEMP1_VECTOR

Exit Function
ERROR_LABEL:
GET_BOND_PRICES_FUNC = Err.number
End Function

Private Function GET_FORWARD_CURVE_FUNC(ByRef FORWARD_MATURITY_VECTOR As Variant, _
ByRef FORWARD_RATES_VECTOR As Variant, _
ByRef MATURITY_VECTOR As Variant)

Dim i As Long
Dim j As Long

Dim k As Long
Dim l As Long

Dim MATCH_FLAG As Boolean
Dim TEMP_VECTOR As Variant 'ForwardCurve

On Error GoTo ERROR_LABEL

l = UBound(FORWARD_MATURITY_VECTOR, 1)
k = UBound(MATURITY_VECTOR, 1)

ReDim TEMP_VECTOR(1 To k - 1, 1 To 1)
For i = 1 To k
    MATCH_FLAG = False
    For j = 1 To l
        If FORWARD_MATURITY_VECTOR(j, 1) = MATURITY_VECTOR(i, 1) Then
            TEMP_VECTOR(i - 1, 1) = FORWARD_RATES_VECTOR(j, 1)
            MATCH_FLAG = True
            Exit For
        End If
    Next j
    If MATCH_FLAG = False And MATURITY_VECTOR(i, 1) > 0 Then
        TEMP_VECTOR(i - 1, 1) = GET_BOOTSTRAP_VALUE_FUNC(FORWARD_MATURITY_VECTOR, _
                          FORWARD_RATES_VECTOR, MATURITY_VECTOR(i, 1))
    End If
Next i

GET_FORWARD_CURVE_FUNC = TEMP_VECTOR

Exit Function
ERROR_LABEL:
GET_FORWARD_CURVE_FUNC = Err.number
End Function

Private Function GET_YIELD_CURVE_FUNC(ByRef MATURITY_VECTOR As Variant, _
ByRef FORWARD_CURVE_VECTOR As Variant)

Dim i As Long
Dim j As Long

Dim TEMP1_VECTOR As Variant 'YieldCurve
Dim TEMP2_VECTOR As Variant 'DiscountCurve

On Error GoTo ERROR_LABEL

j = UBound(MATURITY_VECTOR, 1)

ReDim TEMP1_VECTOR(1 To j - 1, 1 To 1)
ReDim TEMP2_VECTOR(1 To j, 1 To 1)
TEMP2_VECTOR(1, 1) = 1

For i = 1 To j - 1
    TEMP2_VECTOR(i + 1, 1) = TEMP2_VECTOR(i, 1) / (1 + (MATURITY_VECTOR(i + 1, 1) - _
                       MATURITY_VECTOR(i, 1)) * FORWARD_CURVE_VECTOR(i, 1))
    TEMP1_VECTOR(i, 1) = -Log(TEMP2_VECTOR(i + 1, 1)) / MATURITY_VECTOR(i + 1, 1)
Next i
GET_YIELD_CURVE_FUNC = TEMP1_VECTOR

Exit Function
ERROR_LABEL:
GET_YIELD_CURVE_FUNC = Err.number
End Function

Public Function GET_YIELD_OBJ_FUNC(ByRef PARAM_VECTOR As Variant)
Dim i As Long
Dim j As Long

Dim TEMP_SUM As Double

Dim TEMP1_VECTOR As Variant 'ForwardCurve
Dim TEMP2_VECTOR As Variant 'ForwardRatesVec
Dim TEMP3_VECTOR As Variant 'BondCalculatedPrices

On Error GoTo ERROR_LABEL

j = UBound(PUB_BOND_TENOR_VECTOR, 1)
ReDim TEMP2_VECTOR(1 To j, 1 To 1)
For i = 1 To j
    TEMP2_VECTOR(i, 1) = PARAM_VECTOR(i, 1)
Next i

TEMP1_VECTOR = GET_FORWARD_CURVE_FUNC(PUB_BOND_TENOR_VECTOR, TEMP2_VECTOR, PUB_BOND_MATURITY_VECTOR)
TEMP3_VECTOR = GET_BOND_PRICES_FUNC(PUB_BOND_MATURITY_VECTOR, TEMP1_VECTOR, PUB_BOND_PAYMENTS_MATRIX)
TEMP_SUM = 0
For i = 1 To j
    TEMP_SUM = TEMP_SUM + (TEMP3_VECTOR(i, 1) - PUB_BOND_PRICES_VECTOR(i, 1)) ^ 2
Next i
'MyFunction = (PARAM_VECTOR(1, 1) - 4) ^ 2 + (PARAM_VECTOR(2, 1) - 2.7) ^ 4 + _
(PARAM_VECTOR(3, 1) - 6.7) ^ 4
GET_YIELD_OBJ_FUNC = TEMP_SUM

Exit Function
ERROR_LABEL:
GET_YIELD_OBJ_FUNC = Err.number
End Function

'Returns an BOOTSTRAP value of x
'doing a lookup of XDATA_VECTOR -> YDATA_VECTOR

Private Function GET_BOOTSTRAP_VALUE_FUNC(ByRef XDATA_VECTOR As Variant, _
ByRef YDATA_VECTOR As Variant, _
ByVal X_VAL As Double)

Dim i As Single
Dim SROW As Long
Dim NROWS As Long

On Error GoTo ERROR_LABEL

SROW = LBound(XDATA_VECTOR)
NROWS = UBound(XDATA_VECTOR)

If ((X_VAL < XDATA_VECTOR(SROW, 1)) Or _
    (X_VAL > XDATA_VECTOR(NROWS, 1))) Then: GoTo ERROR_LABEL
'GET_BOOTSTRAP_VALUE_FUNC: x is out of bound

If XDATA_VECTOR(SROW, 1) = X_VAL Then
    GET_BOOTSTRAP_VALUE_FUNC = YDATA_VECTOR(SROW, 1)
    Exit Function
End If

For i = SROW To NROWS
    If XDATA_VECTOR(i, 1) >= X_VAL Then
        GET_BOOTSTRAP_VALUE_FUNC = _
            YDATA_VECTOR(i - 1, 1) + (X_VAL - XDATA_VECTOR(i - 1, 1)) / _
            (XDATA_VECTOR(i, 1) - XDATA_VECTOR(i - 1, 1)) * (YDATA_VECTOR(i, 1) - _
            YDATA_VECTOR(i - 1, 1))
        Exit Function
    End If
Next i

Exit Function
ERROR_LABEL:
GET_BOOTSTRAP_VALUE_FUNC = Err.number
End Function
