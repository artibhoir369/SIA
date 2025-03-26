# Use an official Node runtime as a parent image
FROM node:16

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy package.json and package-lock.json to the container
COPY package*.json ./

# Install dependencies (use --production to avoid dev dependencies in production)
RUN npm install --production

# Copy the rest of your app’s source code
COPY . .

# Set environment variable (optional but recommended for production)
ENV NODE_ENV=production

# Expose the port that the backend app will run on
EXPOSE 8081

# Command to run the app
CMD ["npm", "start"]

