const Razorpay = require("razorpay");

module.exports = async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({
      success: false,
      message: "POST required",
    });
  }

  try {
    const keyId = process.env.RAZORPAY_KEY_ID;
    const keySecret = process.env.RAZORPAY_KEY_SECRET;

    if (!keyId || !keySecret) {
      return res.status(500).json({
        success: false,
        error: "Missing Razorpay environment variables",
        keyIdExists: !!keyId,
        secretExists: !!keySecret,
      });
    }

    const razorpay = new Razorpay({
      key_id: keyId,
      key_secret: keySecret,
    });

    const order = await razorpay.orders.create({
      amount: 25000,
      currency: "INR",
      receipt: `farmite_${Date.now()}`,
    });

    return res.status(200).json({
      success: true,
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
      keyId: keyId,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message || "Unknown Razorpay error",
      description: error.description || null,
      statusCode: error.statusCode || null,
      keyIdExists: !!process.env.RAZORPAY_KEY_ID,
      secretExists: !!process.env.RAZORPAY_KEY_SECRET,
    });
  }
};