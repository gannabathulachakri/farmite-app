const Razorpay = require("razorpay");

module.exports = async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ message: "POST required" });
  }

  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;

  const keyIdExists = !!keyId;
  const secretExists = !!keySecret;

  if (!keyIdExists || !secretExists) {
    return res.status(500).json({
      success: false,
      message: "Razorpay environment variables missing",
      keyIdExists,
      secretExists
    });
  }

  try {
    const razorpay = new Razorpay({
      key_id: keyId,
      key_secret: keySecret,
    });

    // Monthly subscription is ₹250
    const amount = 25000;
    const currency = "INR";

    const options = {
      amount: amount, // Amount in paise
      currency: currency,
      receipt: "receipt_" + Date.now(),
    };

    const order = await razorpay.orders.create(options);

    return res.status(200).json({
      success: true,
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
      keyId: keyId // Returning as requested
    });
  } catch (error) {
    console.error("Error creating Razorpay order:", error);
    return res.status(500).json({
      success: false,
      error: error.message,
      keyIdExists,
      secretExists
    });
  }
};