// Mock @supabase/supabase-js before any module that imports it is loaded,
// so tripStore.ts can be required without a real SUPABASE_URL.
jest.mock("@supabase/supabase-js", () => ({
  createClient: jest.fn(() => ({
    from: jest.fn().mockReturnThis(),
    insert: jest.fn().mockResolvedValue({ error: null }),
  })),
}));

// Mock tripStore so we can simulate DB failures independently of Supabase.
jest.mock("../tripStore");

import request from "supertest";
import http from "http";
import app from "../index";
import * as tripStore from "../tripStore";

const mockedInsertTrip = tripStore.insertTrip as jest.MockedFunction<typeof tripStore.insertTrip>;

let server: http.Server;

beforeAll(() => { server = app.listen(0); });
afterAll(() => { server.close(); });

describe("POST /add-trip integration", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedInsertTrip.mockResolvedValue(undefined);
  });

  describe("happy path", () => {
    it("returns 200 with correct carbon value for diesel", async () => {
      // distance=10, fuel_type="diesel", idle_time=2 → 10*2.6 + 2*0.5 = 27
      const res = await request(app)
        .post("/add-trip")
        .send({ distance: 10, fuel_type: "diesel", idle_time: 2, load_weight: 500 });

      expect(res.status).toBe(200);
      expect(res.body).toEqual({ carbon: 27 });
    });

    it("returns 200 with correct carbon value for petrol", async () => {
      // distance=10, fuel_type="petrol", idle_time=2 → 10*2.3 + 2*0.5 = 24
      const res = await request(app)
        .post("/add-trip")
        .send({ distance: 10, fuel_type: "petrol", idle_time: 2, load_weight: 500 });

      expect(res.status).toBe(200);
      expect(res.body).toEqual({ carbon: 24 });
    });

    it("calls insertTrip with the correct record", async () => {
      await request(app)
        .post("/add-trip")
        .send({ distance: 10, fuel_type: "diesel", idle_time: 2, load_weight: 500 });

      expect(mockedInsertTrip).toHaveBeenCalledWith({
        distance: 10,
        idle_time: 2,
        fuel_type: "diesel",
        carbon_kg: 27,
      });
    });
  });

  describe("DB failure resilience (Requirement 7.4)", () => {
    it("still returns 200 with carbon value when insertTrip throws", async () => {
      mockedInsertTrip.mockRejectedValue(new Error("DB connection failed"));

      const res = await request(app)
        .post("/add-trip")
        .send({ distance: 10, fuel_type: "diesel", idle_time: 2, load_weight: 500 });

      expect(res.status).toBe(200);
      expect(res.body).toEqual({ carbon: 27 });
    });

    it("still returns 200 with carbon value when insertTrip rejects with Supabase error", async () => {
      mockedInsertTrip.mockRejectedValue({ message: "Supabase insert error", code: "23505" });

      const res = await request(app)
        .post("/add-trip")
        .send({ distance: 5, fuel_type: "petrol", idle_time: 0, load_weight: 100 });

      // 5*2.3 + 0*0.5 = 11.5
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ carbon: 11.5 });
    });
  });
});
