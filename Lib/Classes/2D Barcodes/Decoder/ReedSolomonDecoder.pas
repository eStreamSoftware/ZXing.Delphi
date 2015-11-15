unit ReedSolomonDecoder;

interface

uses SysUtils, GenericGF;

Type

  TReedSolomonDecoder = class sealed
  public
    constructor Create(field: TGenericGF);
  public
    function decode(received: TArray<Integer>; twoS: Integer): boolean;
  strict private
    function findErrorLocations(errorLocator: TGenericGFPoly): TArray<Integer>;
  strict private
    function findErrorMagnitudes(errorEvaluator: TGenericGFPoly;
      errorLocations: TArray<Integer>): TArray<Integer>;
  private
    function runEuclideanAlgorithm(a: TGenericGFPoly; b: TGenericGFPoly;
      pR: Integer): TArray<TGenericGFPoly>;

  strict private
    field: TGenericGF;

  end;

implementation

{ TReedSolomonDecoder }

constructor TReedSolomonDecoder.Create(field: TGenericGF);
begin
  self.field := field
end;

function TReedSolomonDecoder.decode(received: TArray<Integer>;
  twoS: Integer): boolean;
var
  i, eval, position: Integer;
  poly, syndrome, sigma, omega: TGenericGFPoly;
  sigmaOmega: TArray<TGenericGFPoly>;
  errorLocations: TArray<Integer>;

  syndromeCoefficients, errorMagnitudes: TArray<Integer>;
  noError: boolean;
begin
  poly := TGenericGFPoly.Create(self.field, received);
  syndromeCoefficients := TArray<Integer>.Create();
  SetLength(syndromeCoefficients, twoS);

  noError := true;
  i := 0;
  while ((i < twoS)) do
  begin
    eval := poly.evaluateAt(self.field.exp((i + self.field.GeneratorBase)));
    syndromeCoefficients[((Length(syndromeCoefficients) - 1) - i)] := eval;
    if (eval <> 0) then
      noError := false;
    inc(i)
  end;
  if (not noError) then
  begin
    syndrome := TGenericGFPoly.Create(self.field, syndromeCoefficients);
    sigmaOmega := self.runEuclideanAlgorithm(self.field.buildMonomial(twoS, 1),
      syndrome, twoS);
    if (sigmaOmega = nil) then
    begin
      Result := false;
      exit
    end;
    sigma := sigmaOmega[0];
    errorLocations := self.findErrorLocations(sigma);
    if (errorLocations = nil) then
    begin
      Result := false;
      exit
    end;
    omega := sigmaOmega[1];
    errorMagnitudes := self.findErrorMagnitudes(omega, errorLocations);
    i := 0;
    while (i < Length(errorLocations)) do
    begin
      position := ((Length(received) - 1) - self.field.log(errorLocations[i]));
      if (position < 0) then
      begin
        Result := false;
        exit
      end;
      received[position] := TGenericGF.addOrSubtract(received[position],
        errorMagnitudes[i]);
      inc(i)
    end
  end;
  begin
    Result := true;
    exit
  end
end;

function TReedSolomonDecoder.findErrorLocations(errorLocator: TGenericGFPoly)
  : TArray<Integer>;
var
  numErrors, e, i: Integer;

begin
  numErrors := errorLocator.Degree;

  if (numErrors = 1) then
  begin
    Result := TArray<Integer>.Create(errorLocator.getCoefficient(1));
    exit
  end;

  Result := TArray<Integer>.Create();
  SetLength(Result, numErrors);

  e := 0;
  i := 1;

  while (((i < self.field.Size) and (e < numErrors))) do
  begin

    if (errorLocator.evaluateAt(i) = 0) then
    begin
      Result[e] := self.field.inverse(i);
      inc(e)
    end;

    inc(i);

  end;

  if (e <> numErrors) then
  begin
    Result := nil;
  end;

end;

function TReedSolomonDecoder.findErrorMagnitudes(errorEvaluator: TGenericGFPoly;
  errorLocations: TArray<Integer>): TArray<Integer>;
var
  s, i, xiInverse, denominator, j, term, termPlus1: Integer;

begin
  s := Length(errorLocations);
  Result := TArray<Integer>.Create();
  SetLength(Result, s);

  i := 0;
  while ((i < s)) do
  begin
    xiInverse := self.field.inverse(errorLocations[i]);
    denominator := 1;
    j := 0;
    while ((j < s)) do
    begin
      if (i <> j) then
      begin
        term := self.field.multiply(errorLocations[j], xiInverse);

        if ((term and 1) = 0) then
        begin
          termPlus1 := (term or 1)
        end
        else
        begin
          termPlus1 := (term and (not 1));
        end;

        denominator := self.field.multiply(denominator, termPlus1)

      end;
      inc(j)
    end;

    Result[i] := self.field.multiply(errorEvaluator.evaluateAt(xiInverse),
      self.field.inverse(denominator));
    if (self.field.GeneratorBase <> 0) then
      Result[i] := self.field.multiply(Result[i], xiInverse);
    inc(i)
  end;

  Result := Result;

end;

function TReedSolomonDecoder.runEuclideanAlgorithm(a, b: TGenericGFPoly;
  pR: Integer): TArray<TGenericGFPoly>;
var
  temp, rLastLast, tLastLast, rLast, tLast, t, q, sigma, omega,
    R: TGenericGFPoly;
  denominatorLeadingTerm, dltInverse, degreeDiff, scale, inverse,
    sigmaTildeAtZero: Integer;

begin

  if (a.Degree < b.Degree) then
  begin
    temp := a;
    a := b;
    b := temp
  end;
  rLast := a;
  R := b;
  tLastLast := self.field.Zero;
  t := self.field.One;

  while ((R.Degree >= (pR div 2))) do
  begin
    rLastLast := rLast;
    tLastLast := tLast;
    rLast := R;
    tLast := t;

    if (rLast.isZero) then
    begin
      Result := nil;
      exit
    end;

    R := rLastLast;
    q := self.field.Zero;
    denominatorLeadingTerm := rLast.getCoefficient(rLast.Degree);
    dltInverse := self.field.inverse(denominatorLeadingTerm);

    while (((R.Degree >= rLast.Degree) and not R.isZero)) do
    begin
      degreeDiff := (R.Degree - rLast.Degree);
      scale := self.field.multiply(R.getCoefficient(R.Degree), dltInverse);
      q := q.addOrSubtract(self.field.buildMonomial(degreeDiff, scale));
      R := R.addOrSubtract(rLast.multiplyByMonomial(degreeDiff, scale))
    end;

    t := q.multiply(tLast).addOrSubtract(tLastLast);

    if (R.Degree >= rLast.Degree) then
    begin
      Result := nil;
      exit
    end
  end;

  sigmaTildeAtZero := t.getCoefficient(0);
  if (sigmaTildeAtZero = 0) then
  begin
    Result := nil;
    exit
  end;

  inverse := self.field.inverse(sigmaTildeAtZero);
  sigma := t.multiply(inverse);
  omega := R.multiply(inverse);

  Result := TArray<TGenericGFPoly>.Create(sigma, omega);

end;

end.