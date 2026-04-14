import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import addTripRouter from './routes/addTrip';

const app = express();
app.use(cors());
app.use(express.json());

app.use(addTripRouter);

export default app;

// Only start the server when this file is run directly, not when imported by tests
if (require.main === module) {
  const PORT = process.env.PORT ?? 3000;
  app.listen(PORT, () => {
    console.log(`CarbonChain backend listening on port ${PORT}`);
  });
}
