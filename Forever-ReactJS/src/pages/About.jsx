//About.jsx
import { assets } from "../assets/frontend_assets/assets";
import Title from "../components/Title";

const About = () => {
  return (
    <>
      {/* About Us Section */}
      <div className="text-2xl text-center pt-8 border-t">
        <Title text1="about" text2="us" />
      </div>

      <div className="my-10 flex flex-col md:flex-row gap-10 px-4 md:px-8">
        {/* About Image */}
        <img 
          className="w-full md:max-w-[450px] mx-auto rounded-lg shadow-md" 
          src={assets.about_img} 
          alt="About Us" 
        />

        {/* About Description */}
        <div className="flex flex-col justify-center gap-6 md:w-2/3 text-gray-700">
          <p>
            Welcome to our company! We are passionate about delivering high-quality products and exceptional services tailored to meet your unique needs. With a focus on innovation and reliability, we aim to exceed your expectations at every step.
          </p>
          <p>
            Our experienced team is committed to building lasting relationships with our customers, fostering trust, and creating value through outstanding solutions. Your satisfaction is at the heart of everything we do.
          </p>
          <b className="text-gray-800 text-lg">Our Mission</b>
          <p>
            Our mission is to empower our customers with reliable, efficient, and innovative solutions that make a positive impact. We are dedicated to driving excellence and creating opportunities for growth and success.
          </p>
        </div>
      </div>

      {/* Why Choose Us Section */}
      <div className="text-center py-8">
        <Title text1="why" text2="choose us" />
      </div>

      <div className="flex flex-col md:flex-row gap-8 px-4 md:px-8 mb-20">
        {/* Quality Assurance */}
        <div className="border px-6 md:px-10 py-8 flex flex-col gap-4 rounded-lg shadow-md hover:shadow-lg transition-shadow duration-200">
          <b className="text-lg text-gray-800">Quality Assurance:</b>
          <p className="text-gray-600">
            We prioritize excellence in every aspect of our work. Our rigorous quality assurance processes ensure that every product and service we deliver meets the highest standards of reliability and performance.
          </p>
        </div>

        {/* Convenience */}
        <div className="border px-6 md:px-10 py-8 flex flex-col gap-4 rounded-lg shadow-md hover:shadow-lg transition-shadow duration-200">
          <b className="text-lg text-gray-800">Convenience:</b>
          <p className="text-gray-600">
            Your convenience is our priority. We offer streamlined services and easy-to-use products designed to save you time and effort, providing you with a hassle-free experience.
          </p>
        </div>

        {/* Exceptional Customer Service */}
        <div className="border px-6 md:px-10 py-8 flex flex-col gap-4 rounded-lg shadow-md hover:shadow-lg transition-shadow duration-200">
          <b className="text-lg text-gray-800">Exceptional Customer Service:</b>
          <p className="text-gray-600">
            Our dedicated customer support team is here to assist you every step of the way. We pride ourselves on delivering personalized, friendly, and responsive service that makes a difference.
          </p>
        </div>
      </div>
    </>
  );
};

export default About;
