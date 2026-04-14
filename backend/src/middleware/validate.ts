import { Request, Response, NextFunction } from "express";

const REQUIRED_FIELDS = ["distance", "fuel_type", "idle_time", "load_weight"] as const;
const VALID_FUEL_TYPES = ["diesel", "petrol"] as const;

export function validateTripRequest(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const body = req.body;

  for (const field of REQUIRED_FIELDS) {
    if (body[field] === undefined || body[field] === null || body[field] === "") {
      res.status(400).json({ error: `Missing required field: ${field}` });
      return;
    }
  }

  if (!VALID_FUEL_TYPES.includes(body.fuel_type)) {
    res.status(400).json({ error: `Invalid fuel_type: must be "diesel" or "petrol"` });
    return;
  }

  if (typeof body.distance !== "number" || isNaN(body.distance)) {
    res.status(400).json({ error: "Invalid field: distance must be numeric" });
    return;
  }

  if (typeof body.idle_time !== "number" || isNaN(body.idle_time)) {
    res.status(400).json({ error: "Invalid field: idle_time must be numeric" });
    return;
  }

  // engine_efficiency is optional — default to 10 km/L if not provided
  if (body.engine_efficiency !== undefined) {
    if (typeof body.engine_efficiency !== "number" || isNaN(body.engine_efficiency) || body.engine_efficiency <= 0) {
      res.status(400).json({ error: "Invalid field: engine_efficiency must be a positive number (km/L)" });
      return;
    }
  }

  next();
}
