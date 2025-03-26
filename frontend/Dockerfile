# Use node to build the React app
FROM node:16 as build

# Set the working directory in the container
WORKDIR /app

# Copy package.json and package-lock.json for installing dependencies
COPY package*.json ./

# Set npm timeout settings to handle network issues
RUN npm config set fetch-timeout 600000 && npm config set fetch-retries 5

# Install dependencies using npm ci for consistency and performance
RUN npm ci

# Copy the rest of the React app's source code
COPY . .

# Build the app for production
RUN npm run build

# Use nginx to serve the built React app
FROM nginx:alpine

# Copy the built app to nginx's public directory
COPY --from=build /app/build /usr/share/nginx/html

# Expose port 80 (the standard HTTP port for serving React apps via Nginx)
EXPOSE 80

# Run nginx in the foreground (necessary for Docker containers to keep running)
CMD ["nginx", "-g", "daemon off;"]

