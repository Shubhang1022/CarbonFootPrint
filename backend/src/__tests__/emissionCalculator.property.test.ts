import * as fc from "fast-check";
import { calculateCarbon } from "../emissionCalculator";

const DIESEL_FACTOR = 2.6;
const PETROL_FACTOR = 2.3;

// Feature: carbon-chain, Property 1: Linearity — doubling distance doubles the driving component of carbon
describe("Property 1: Linearity", () => {
  it("doubling distance doubles the driving component of carbon", () => {
    // Validates: Requirements 6.1, 6.2, 6.3
    fc.assert(
      fc.property(
        fc.float({ min: 0, max: 1000, noNaN: true }),
        fc.oneof(fc.constant("diesel" as const), fc.constant("petrol" as const)),
        fc.float({ min: 0, max: 500, noNaN: true }),
        (distance, fuelType, idleTime) => {
          const single = calculateCarbon(distance, fuelType, idleTime);
          const doubled = calculateCarbon(distance * 2, fuelType, idleTime);

          const factor = fuelType === "diesel" ? DIESEL_FACTOR : PETROL_FACTOR;
          const drivingComponent = distance * factor;
          const doubledDrivingComponent = (distance * 2) * factor;

          // The difference between doubled and single should equal the original driving component
          const diff = doubled - single;
          return Math.abs(diff - drivingComponent) < 1e-9 &&
            Math.abs(doubledDrivingComponent - 2 * drivingComponent) < 1e-9;
        }
      ),
      { numRuns: 20 }
    );
  });
});

// Feature: carbon-chain, Property 2: Idle contribution — carbon increases by 0.5 per additional idle minute regardless of fuel type
describe("Property 2: Idle contribution", () => {
  it("carbon increases by 0.5 per additional idle minute regardless of fuel type", () => {
    // Validates: Requirements 6.1
    fc.assert(
      fc.property(
        fc.float({ min: 0, max: 1000, noNaN: true }),
        fc.oneof(fc.constant("diesel" as const), fc.constant("petrol" as const)),
        fc.float({ min: 0, max: 500, noNaN: true }),
        fc.float({ min: Math.fround(0.001), max: 100, noNaN: true }),
        (distance, fuelType, idleTime, extraIdle) => {
          const base = calculateCarbon(distance, fuelType, idleTime);
          const withExtra = calculateCarbon(distance, fuelType, idleTime + extraIdle);
          const diff = withExtra - base;
          return Math.abs(diff - extraIdle * 0.5) < 1e-9;
        }
      ),
      { numRuns: 20 }
    );
  });
});

// Feature: carbon-chain, Property 3: Diesel always produces more carbon than petrol for the same inputs
describe("Property 3: Diesel > Petrol", () => {
  it("diesel always produces more carbon than petrol for the same inputs", () => {
    // Validates: Requirements 6.2, 6.3
    fc.assert(
      fc.property(
        fc.float({ min: Math.fround(0.001), max: 1000, noNaN: true }),
        fc.float({ min: 0, max: 500, noNaN: true }),
        (distance, idleTime) => {
          const dieselCarbon = calculateCarbon(distance, "diesel", idleTime);
          const petrolCarbon = calculateCarbon(distance, "petrol", idleTime);
          return dieselCarbon > petrolCarbon;
        }
      ),
      { numRuns: 20 }
    );
  });
});
