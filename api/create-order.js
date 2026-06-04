const Razorpay = require("razorpay");

module.exports = async function handler(req, res) {

  if (req.method !== "POST") {
    return res.status(405).json({
      success:false,
      message:"POST required"
    });
  }

  try {

    const razorpay = new Razorpay({
      key_id: process.env.RAZORPAY_KEY_ID,
      key_secret: process.env.RAZORPAY_KEY_SECRET,
    });

    const order = await razorpay.orders.create({
      amount: 25000,
      currency: "INR",
      receipt: "farmite_" + Date.now(),
    });

    return res.json({
      success:true,
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
      keyId: process.env.RAZORPAY_KEY_ID
    });

  } catch (error) {

    console.log("RAZORPAY ERROR:", error);

    return res.status(500).json({
      success:false,
      error:error.message,
      description:error.description,
      keyIdExists:!!process.env.RAZORPAY_KEY_ID,
      secretExists:!!process.env.RAZORPAY_KEY_SECRET
    });
  }
}