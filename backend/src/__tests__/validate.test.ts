import { Request, Response, NextFunction } from "express";
import { validateTripRequest } from "../middleware/validate";

// Helper to create mock req/res/next
function makeReq(body: Record<string, unknown>): Request {
  return { body } as Request;
}

function makeRes(): { res: Response; status: jest.Mock; json: jest.Mock } {
  const json = jest.fn();
  const status = jest.fn().mockReturnValue({ json });
  const res = { status } as unknown as Response;
  return { res, status, json };
}

function makeNext(): NextFunction {
  return jest.fn();
}

const VALID_BODY = {
  distance: 10,
  fuel_type: "diesel",
  idle_time: 2,
  load_weight: 500,
};

// Requirements 6.4 — Missing required fields → HTTP 400
describe("validateTripRequest — missing required fields (Req 6.4)", () => {
  const requiredFields = ["distance", "fuel_type", "idle_time", "load_weight"] as const;

  for (const field of requiredFields) {
    it(`returns 400 when ${field} is missing`, () => {
      const body = { ...VALID_BODY };
      delete (body as Record<string, unknown>)[field];

      const req = makeReq(body);
      const { res, status, json } = makeRes();
      const next = makeNext();

      validateTripRequest(req, res, next);

      expect(status).toHaveBeenCalledWith(400);
      expect(json).toHaveBeenCalledWith(
        expect.objectContaining({ error: expect.stringContaining(field) })
      );
      expect(next).not.toHaveBeenCalled();
    });

    it(`returns 400 when ${field} is null`, () => {
      const body = { ...VALID_BODY, [field]: null };

      const req = makeReq(body);
      const { res, status, json } = makeRes();
      const next = makeNext();

      validateTripRequest(req, res, next);

      expect(status).toHaveBeenCalledWith(400);
      expect(json).toHaveBeenCalledWith(
        expect.objectContaining({ error: expect.any(String) })
      );
      expect(next).not.toHaveBeenCalled();
    });

    it(`returns 400 when ${field} is empty string`, () => {
      const body = { ...VALID_BODY, [field]: "" };

      const req = makeReq(body);
      const { res, status, json } = makeRes();
      const next = makeNext();

      validateTripRequest(req, res, next);

      expect(status).toHaveBeenCalledWith(400);
      expect(next).not.toHaveBeenCalled();
    });
  }
});

// Requirements 6.5 — Invalid fuel_type → HTTP 400
describe("validateTripRequest — invalid fuel_type (Req 6.5)", () => {
  const invalidFuelTypes = ["gasoline", "electric", "LPG", "DIESEL", "Petrol", ""];

  for (const fuelType of invalidFuelTypes) {
    it(`returns 400 for fuel_type "${fuelType}"`, () => {
      const body = { ...VALID_BODY, fuel_type: fuelType };

      const req = makeReq(body);
      const { res, status, json } = makeRes();
      const next = makeNext();

      validateTripRequest(req, res, next);

      expect(status).toHaveBeenCalledWith(400);
      expect(json).toHaveBeenCalledWith(
        expect.objectContaining({ error: expect.any(String) })
      );
      expect(next).not.toHaveBeenCalled();
    });
  }

  it("accepts diesel as valid fuel_type", () => {
    const req = makeReq({ ...VALID_BODY, fuel_type: "diesel" });
    const { res } = makeRes();
    const next = makeNext();

    validateTripRequest(req, res, next);

    expect(next).toHaveBeenCalled();
  });

  it("accepts petrol as valid fuel_type", () => {
    const req = makeReq({ ...VALID_BODY, fuel_type: "petrol" });
    const { res } = makeRes();
    const next = makeNext();

    validateTripRequest(req, res, next);

    expect(next).toHaveBeenCalled();
  });
});

// Requirements 6.6 — Non-numeric distance/idle_time → HTTP 400
describe("validateTripRequest — non-numeric distance/idle_time (Req 6.6)", () => {
  it("returns 400 when distance is a string", () => {
    const req = makeReq({ ...VALID_BODY, distance: "ten" });
    const { res, status, json } = makeRes();
    const next = makeNext();

    validateTripRequest(req, res, next);

    expect(status).toHaveBeenCalledWith(400);
    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({ error: expect.stringContaining("distance") })
    );
    expect(next).not.toHaveBeenCalled();
  });

  it("returns 400 when distance is NaN", () => {
    const req = makeReq({ ...VALID_BODY, distance: NaN });
    const { res, status } = makeRes();
    const next = makeNext();

    validateTripRequest(req, res, next);

    expect(status).toHaveBeenCalledWith(400);
    expect(next).not.toHaveBeenCalled();
  });

  it("returns 400 when idle_time is a string", () => {
    const req = makeReq({ ...VALID_BODY, idle_time: "two" });
    const { res, status, json } = makeRes();
    const next = makeNext();

    validateTripRequest(req, res, next);

    expect(status).toHaveBeenCalledWith(400);
    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({ error: expect.stringContaining("idle_time") })
    );
    expect(next).not.toHaveBeenCalled();
  });

  it("returns 400 when idle_time is NaN", () => {
    const req = makeReq({ ...VALID_BODY, idle_time: NaN });
    const { res, status } = makeRes();
    const next = makeNext();

    validateTripRequest(req, res, next);

    expect(status).toHaveBeenCalledWith(400);
    expect(next).not.toHaveBeenCalled();
  });

  it("accepts numeric distance and idle_time (integers)", () => {
    const req = makeReq({ ...VALID_BODY, distance: 0, idle_time: 0 });
    const { res } = makeRes();
    const next = makeNext();

    validateTripRequest(req, res, next);

    expect(next).toHaveBeenCalled();
  });

  it("accepts numeric distance and idle_time (floats)", () => {
    const req = makeReq({ ...VALID_BODY, distance: 12.5, idle_time: 3.7 });
    const { res } = makeRes();
    const next = makeNext();

    validateTripRequest(req, res, next);

    expect(next).toHaveBeenCalled();
  });
});

// Happy path — all valid fields → calls next()
describe("validateTripRequest — valid request", () => {
  it("calls next() for a fully valid body", () => {
    const req = makeReq(VALID_BODY);
    const { res } = makeRes();
    const next = makeNext();

    validateTripRequest(req, res, next);

    expect(next).toHaveBeenCalled();
  });
});
