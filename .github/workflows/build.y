name: build
on:
  push:
    branches:
      - "main"

jobs:
  images:
    runs-on: self-hosted
    env:
      REGISTRY: 436866023604.dkr.ecr.eu-central-1.amazonaws.com
    steps:
      - uses: actions/checkout@v2
        with:
          fetch-depth: 1
      - uses: unfor19/install-aws-cli-action@v1
      - name: Login to Amazon ECR
        uses: aws-actions/amazon-ecr-login@v1.3.3
            - name: Cache local Gradle repository
        uses: actions/cache@v2
        with:
          path: ~/.m2/repository
          key: ${{ runner.os }}-Gradle-${{ hashFiles('**/build.gradle') }}
          restore-keys: |
            ${{ runner.os }}-Gradle-
      - name: Set up JDK 13
        uses: actions/setup-java@v2
        with:
          java-version: '13'
          distribution: 'adopt'
      - name: Validate Gradle wrapper
        uses: gradle/wrapper-validation-action@e6e38bacfdf1a337459f332974bb2327a31aaf4b
      - name: Build with Gradle
        env:
          CI: false
        run: ./gradlew clean jibDockerBuild--no-daemon --image ${{ env.REGISTRY }}/${{ github.event.repository.name }} -P version=ci-${GITHUB_SHA::6}
      - name: Push Docker image to Amazon ECR
        run: docker push ${{ env.REGISTRY }}/${{ github.event.repository.name }}:ci-${GITHUB_SHA::6}
  update_tag:
    needs: ["images"]
    runs-on: self-hosted
    steps:
      - name: Masking token
        run: |
          INP_GIT_TOKEN=$(echo ${ODD_GIT_TOKEN} | base64 -d)
          echo ::add-mask::$INP_GIT_TOKEN
          echo MASKED_ODD_GIT_TOKEN="$INP_GIT_TOKEN" >> $GITHUB_ENV
      - uses: actions/checkout@v2
        with:
          repository: provectus/environment-state
          token: ${{ env.MASKED_ODD_GIT_TOKEN }}
      - run: |
          sed -i "s/tag:.*/tag: ci-${GITHUB_SHA::6}/" odd-platform.yaml
          git config user.name github-actions
          git config user.email github-actions@github.com
          git add .
          git commit -m "update tag"
          git push
